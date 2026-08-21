#!/usr/bin/env bash
# Chapter 12 - every error the chapter prints, on purpose.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

vault secrets enable transit >/dev/null 2>&1 || true

# Start from a known key. A key left over from a previous run has already
# been rotated, and then the version-specific cases below prove nothing -
# which is exactly how the first attempt at this script fooled itself.
for k in wwr-orders wwr-sign; do
  vault write transit/keys/$k/config deletion_allowed=true >/dev/null 2>&1 || true
  vault delete transit/keys/$k >/dev/null 2>&1 || true
done
vault write -f transit/keys/wwr-orders >/dev/null
vault write transit/keys/wwr-sign type=ed25519 >/dev/null

wwr_case "invalid ciphertext on encryption - the plaintext was not base64"
wwr_expect "illegal base64 data" vault write transit/encrypt/wwr-orders plaintext=Hamburg
echo "Everything going in and coming out is encoded:"
CT=$(vault write -field=ciphertext transit/encrypt/wwr-orders \
      plaintext="$(printf 'Hamburg' | base64)")
printf '  ciphertext: %s\n' "$CT"

wwr_case "the decrypted value looks like gibberish"
raw=$(vault write -field=plaintext transit/decrypt/wwr-orders ciphertext="$CT")
printf '  as returned : %s\n' "$raw"
printf '  decoded     : %s\n' "$(printf '%s' "$raw" | base64 --decode)"

wwr_case "invalid ciphertext: no prefix"
echo "The vault:vN: prefix is part of the ciphertext, not decoration:"
wwr_expect "invalid ciphertext" vault write transit/decrypt/wwr-orders \
  ciphertext="$(printf '%s' "$CT" | sed 's/^vault:v[0-9]*://')"

wwr_case "ciphertext or signature version is disallowed by policy (too old)"
vault write -f transit/keys/wwr-orders/rotate >/dev/null
vault write transit/keys/wwr-orders/config min_decryption_version=2 >/dev/null
echo "min_decryption_version is now 2, and \$CT was encrypted with v1:"
wwr_expect "too old" vault write transit/decrypt/wwr-orders ciphertext="$CT"
echo "If any record still carries v1, that data is gone. There is no"
echo "recovery - the point of the setting is that there is none."
vault write transit/keys/wwr-orders/config min_decryption_version=1 >/dev/null
printf '  lowered again, and the same ciphertext decrypts: %s\n' \
  "$(vault write -field=plaintext transit/decrypt/wwr-orders ciphertext="$CT" | base64 --decode)"
echo "Which is worth knowing: the setting is a policy, not a shredder."

wwr_case "unsupported operation when signing"
echo "wwr-orders is symmetric (aes256-gcm96). Signing needs a key that can:"
wwr_expect "does not support signing" vault write transit/sign/wwr-orders \
  input="$(printf 'x' | base64)"
echo "The ed25519 key signs:"
vault write -field=signature transit/sign/wwr-sign \
  input="$(printf 'x' | base64)" | cut -c1-48

wwr_case "no handler for route transit/encrypt/..."
echo "Either the engine is not mounted there, or the key does not exist."
echo "A key that does not exist:"
wwr_run vault write transit/encrypt/wwr-nosuchkey plaintext="$(printf 'x' | base64)"
echo "A mount that does not exist:"
wwr_expect "no handler for route" vault write nosuchmount/encrypt/k \
  plaintext="$(printf 'x' | base64)"
echo "vault secrets list settles which of the two it is."

vault delete transit/keys/wwr-orders >/dev/null 2>&1 || true
vault delete transit/keys/wwr-sign >/dev/null 2>&1 || true
wwr_done
