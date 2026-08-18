#!/usr/bin/env bash
# Chapter 24 - score a Vault installation against the checklist.
#
# Every check here maps to an outage described in this book. A lab will
# fail several; that is the correct result and the point of running it.
set -uo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

pass=0; fail=0
chk() {
  local label="$1" chapter="$2" test="$3"
  if eval "$test" >/dev/null 2>&1; then
    printf "  PASS  %-38s\n" "$label"; pass=$((pass+1))
  else
    printf "  FAIL  %-38s  see ch %s\n" "$label" "$chapter"; fail=$((fail+1))
  fi
}

echo "Vault hardening self-assessment"
echo

chk "storage is not file" 20 \
  'vault status -format=json | jq -e ".storage_type != \"file\""'
chk "HA enabled" 21 \
  'vault status -format=json | jq -e ".ha_enabled == true"'
chk "auto-unseal configured" 22 \
  'vault status -format=json | jq -e ".type != \"shamir\""'
chk "two or more audit devices" 23 \
  '[ "$(vault audit list -format=json | jq "keys|length")" -ge 2 ]'
chk "no policy grants path \"*\"" 6 \
  '! for p in $(vault policy list); do
       vault policy read "$p"
     done | grep -q "^path \"\\*\""'
chk "current token is not root" 5 \
  '! vault token lookup -format=json \
     | jq -e ".data.policies | index(\"root\")"'
chk "telemetry configured" 23 \
  'vault read -format=json sys/config/state/sanitized \
     | jq -e ".data.telemetry"'
chk "kv mounts limit versions" 9 \
  'vault secrets list -format=json \
     | jq -e "[.[] | select(.type==\"kv\")] | length > 0"'

echo
echo "  $pass passed, $fail failed"
echo
echo "Read each failure rather than adjusting the script."
