#!/usr/bin/env bash
# Chapter 4 - every error the chapter prints, on purpose.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env
ROOT="$VAULT_TOKEN"

vault secrets enable -path=meridian -version=2 kv >/dev/null 2>&1 || true
vault kv put meridian/tracking a=b >/dev/null
vault auth enable userpass >/dev/null 2>&1 || true
vault write auth/userpass/users/wwr password=lab-pw policies=default >/dev/null

wwr_case "http: server gave HTTP response to HTTPS client"
VAULT_ADDR="https://${VAULT_ADDR#*://}" \
  wwr_expect "gave HTTP response to HTTPS client" vault status

wwr_case "permission denied immediately after a successful login"
echo "VAULT_TOKEN is set to something invalid and outranks the token file."
T=$(VAULT_TOKEN='' vault login -field=token -method=userpass \
      username=wwr password=lab-pw)
echo "login succeeded, token ...${T: -6}"
VAULT_TOKEN='hvs.staleleftover' wwr_expect "permission denied" \
  vault kv get meridian/tracking
echo "The fix is one line, and it is the order that matters:"
echo '  unset VAULT_TOKEN   # before vault login, not after'

wwr_case "404 on a path the CLI can read"
echo "The CLI shows you the request it would make:"
wwr_run vault kv get -output-curl-string meridian/tracking
code=$(curl -s -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $ROOT" \
        "$VAULT_ADDR/v1/meridian/tracking")
printf 'without data/ : %s\n' "$code"
code=$(curl -s -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $ROOT" \
        "$VAULT_ADDR/v1/meridian/data/tracking")
printf 'with data/    : %s\n' "$code"

wwr_case "unsupported operation when listing"
echo "GET where Vault expected LIST, on a path that is genuinely a list:"
curl -s -o /tmp/wwr -w '  HTTP %{http_code}  ' -H "X-Vault-Token: $ROOT" \
  "$VAULT_ADDR/v1/sys/policies/acl"; head -c 120 /tmp/wwr; echo
echo "the same path with ?list=true:"
curl -s -o /dev/null -w '  HTTP %{http_code}\n' -H "X-Vault-Token: $ROOT" \
  "$VAULT_ADDR/v1/sys/policies/acl?list=true"
echo
echo "On a key/value v2 mount the wording differs - Vault answers with a"
echo "warning rather than 405, and the hint is to list metadata/, not data/:"
curl -s -H "X-Vault-Token: $ROOT" "$VAULT_ADDR/v1/meridian/metadata" \
  | sed -n '1,2p' | cut -c1-160

wwr_case "403 permission denied on a request you thought was authenticated"
echo "No token at all - and a misspelled header looks identical:"
curl -s -o /tmp/wwr -w '  no header    HTTP %{http_code}  ' \
  "$VAULT_ADDR/v1/meridian/data/tracking"; cat /tmp/wwr; echo
curl -s -o /tmp/wwr -w '  X_Vault_Token HTTP %{http_code}  ' \
  -H "X_Vault_Token: $ROOT" "$VAULT_ADDR/v1/meridian/data/tracking"; cat /tmp/wwr; echo
echo "Both 403, both 'permission denied'. A missing token and an"
echo "insufficient one are indistinguishable from the message alone."

wwr_case "the UI shows not authorized for a path you can read"
wwr_policy read-only 'path "meridian/data/tracking" { capabilities = ["read"] }'
T=$(wwr_token read-only)
wwr_caps "$T" meridian/data/tracking
wwr_caps "$T" meridian/metadata
echo "read is enough for an application and not enough for a tree."
wwr_done
