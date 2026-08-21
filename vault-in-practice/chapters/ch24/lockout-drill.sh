#!/usr/bin/env bash
# Chapter 24 - revoke the root token, get locked out, come back.
#
# This one builds its own throwaway Vault under /tmp, because it ends
# with a Vault that has no way in. Do not point it at your lab.
#
# It is the only recovery in this book that works with nothing but the
# unseal keys, and the only one worth rehearsing before you need it.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

IMG="hashicorp/vault:1.18"
PORT="${WWR_PORT:-18240}"
W=$(mktemp -d)
# Vault writes its storage as another uid, so the removal happens in a
# container rather than as you.
cleanup() {
  docker rm -f wwr24 >/dev/null 2>&1
  docker run --rm -v "$W:/w" alpine:3.20 sh -c 'rm -rf /w/*' >/dev/null 2>&1
  rmdir "$W" 2>/dev/null || true
}
trap cleanup EXIT
mkdir -p "$W/config" "$W/data"; chmod 777 "$W/data"
cat > "$W/config/vault.hcl" <<CFG
disable_mlock = true
storage "file" { path = "/vault/data" }
listener "tcp" { address = "0.0.0.0:8200"  tls_disable = true }
api_addr = "http://127.0.0.1:8200"
CFG

docker rm -f wwr24 >/dev/null 2>&1
docker run -d --rm --name wwr24 -p "$PORT:8200" --cap-add IPC_LOCK \
  -v "$W/config:/vault/config:ro" -v "$W/data:/vault/data" "$IMG" \
  vault server -config=/vault/config/vault.hcl >/dev/null
export VAULT_ADDR="http://127.0.0.1:$PORT"
unset VAULT_CACERT
for _ in $(seq 30); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$VAULT_ADDR/v1/sys/health" 2>/dev/null)" = "501" ] && break
  sleep 1
done
vault operator init -format=json -key-shares=3 -key-threshold=2 > "$W/init.json"
key() { jq -r ".unseal_keys_b64[$1]" "$W/init.json"; }
for i in 0 1; do vault operator unseal "$(key $i)" >/dev/null; done
VAULT_TOKEN=$(jq -r .root_token "$W/init.json"); export VAULT_TOKEN
echo "A throwaway Vault: 3 shares, threshold 2, unsealed."

printf '\n== the order that avoids all of this\n'
echo "Before revoking a root token, build the way back in and USE it:"
echo "  1. an admin policy"
echo "  2. an auth method the humans can log in with"
echo "  3. log in that way and confirm it works"
echo "  4. only then revoke the root token"
echo "This drill deliberately skips all four."

printf '\n== revoking the root token with no other way in\n'
vault token revoke "$VAULT_TOKEN" >/dev/null 2>&1
echo '$ vault secrets list'
vault secrets list 2>&1 | sed -n '1,6p' | grep -v '^$' | sed 's/^/  /'
echo
echo "That is the whole installation. Not sealed - sealing is recoverable"
echo "by unsealing. This is an unsealed Vault that nobody can talk to."

printf '\n== coming back, with nothing but the unseal keys\n'
unset VAULT_TOKEN
INIT=$(vault operator generate-root -init -format=json)
NONCE=$(printf '%s' "$INIT" | jq -r .nonce)
OTP=$(printf '%s' "$INIT" | jq -r .otp)
printf '  started: nonce %s…  otp %s…\n' "${NONCE:0:12}" "${OTP:0:8}"
echo "  the OTP exists once, here, and is never stored. Lose it and you"
echo "  start again - which is the point of it."
ENC=""
for i in 0 1; do
  R=$(vault operator generate-root -nonce="$NONCE" -format=json "$(key $i)")
  printf '  share %s: %s  complete=%s\n' "$((i+1))" \
    "$(printf '%s' "$R" | jq -r '"\(.progress)/\(.required)"')" \
    "$(printf '%s' "$R" | jq -r .complete)"
  ENC=$(printf '%s' "$R" | jq -r .encoded_token)
done
NEW=$(vault operator generate-root -decode="$ENC" -otp="$OTP")
printf '  new root token: %s…\n' "${NEW:0:12}"
echo
echo '$ VAULT_TOKEN=<new> vault secrets list'
VAULT_TOKEN="$NEW" vault secrets list 2>&1 | sed -n '1,3p' | sed 's/^/  /'

printf '\n== what this drill is really about\n'
echo "It needed a threshold of unseal keys, from separate people, at"
echo "short notice. If that is not something your organisation can do"
echo "today, this recovery does not exist for you - and the finding is"
echo "not about root tokens at all. It is Chapter 22's key custody."
echo
echo "Revoke the new token when you are done. On a real Vault:"
echo "  \$ vault token revoke -self"
