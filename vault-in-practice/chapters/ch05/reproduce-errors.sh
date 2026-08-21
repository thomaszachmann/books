#!/usr/bin/env bash
# Chapter 5 - every error the chapter prints, on purpose.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

wwr_case "batch tokens cannot be renewed"
B=$(vault token create -policy=default -type=batch -ttl=1h -field=token)
echo "A batch token is not tracked, so there is nothing to renew:"
VAULT_TOKEN=$B wwr_expect "batch tokens cannot be renewed" vault token renew

wwr_case "permission denied on a token that worked five minutes ago"
echo "Cause 1 of 3: the parent was revoked and the child went with it."
# The parent needs permission to create a child, or the demonstration
# fails on the wrong error and teaches the wrong thing.
wwr_policy parent 'path "auth/token/create" { capabilities = ["create","update"] }'
P=$(vault token create -policy=wwr-parent -ttl=1h -field=token)
C=$(VAULT_TOKEN=$P vault token create -policy=default -ttl=1h -field=token)
VAULT_TOKEN=$C vault token lookup >/dev/null 2>&1 && echo "   child works"
vault token revoke "$P" >/dev/null
VAULT_TOKEN=$C wwr_expect "permission denied" vault token lookup
echo "Cause 2: num_uses ran out - and failed requests count."
U=$(vault token create -policy=default -use-limit=2 -field=token)
VAULT_TOKEN=$U vault token lookup >/dev/null 2>&1 && echo "   use 1 of 2"
VAULT_TOKEN=$U vault token lookup >/dev/null 2>&1 && echo "   use 2 of 2"
VAULT_TOKEN=$U wwr_expect "permission denied" vault token lookup

wwr_case "batch tokens cannot create more tokens"
wwr_policy cc 'path "auth/token/create" { capabilities = ["create","update"] }'
S=$(wwr_token cc)
B=$(vault token create -policy=wwr-cc -type=batch -field=token)
echo "A service token with that policy can:"
VAULT_TOKEN=$S vault token create -policy=default -field=token >/dev/null \
  && echo "   ok: service token created a child"
echo "A batch token with the same policy cannot:"
VAULT_TOKEN=$B wwr_expect "batch tokens cannot create more tokens" \
  vault token create -policy=default

wwr_case "permission denied when creating an orphan token"
wwr_policy orphan 'path "auth/token/create-orphan" { capabilities = ["create","update"] }'
T=$(wwr_token orphan)
echo "create-orphan is root-protected: it needs sudo as well."
wwr_caps "$T" auth/token/create-orphan
VAULT_TOKEN=$T wwr_expect "permission denied" vault token create -orphan -policy=default

wwr_case "the token expires far sooner than requested"
echo "token_explicit_max_ttl caps at issue time:"
vault write auth/token/roles/wwr-hard allowed_policies=default \
  token_explicit_max_ttl=60s >/dev/null
T=$(vault token create -role=wwr-hard -ttl=8h -field=token)
printf '  asked 8h, got %s s\n' \
  "$(vault token lookup -format=json "$T" | jq -r .data.creation_ttl)"
echo "token_max_ttl does not - it caps renewal, so the surprise is later:"
vault write auth/token/roles/wwr-soft allowed_policies=default \
  token_max_ttl=60s >/dev/null
T=$(vault token create -role=wwr-soft -ttl=8h -field=token)
printf '  asked 8h, got %s s\n' \
  "$(vault token lookup -format=json "$T" | jq -r .data.creation_ttl)"
echo "And the system default is 768h, whatever you ask for:"
printf '  asked 2000h, got %s s (= %s h)\n' \
  "$(vault token create -policy=default -ttl=2000h -format=json | jq -r .auth.lease_duration)" 768
vault delete auth/token/roles/wwr-hard >/dev/null
vault delete auth/token/roles/wwr-soft >/dev/null

wwr_case "revoking by accessor reports success and does nothing"
echo '$ vault token revoke -accessor nonsense'
vault token revoke -accessor nonsense 2>&1 | head -1
echo "Read the parenthesis. Over the API the truth is a warning, not an error:"
curl -s -o /tmp/wwr -w '  HTTP %{http_code}  ' -H "X-Vault-Token: $VAULT_TOKEN" \
  -X POST -d '{"accessor":"nonsense"}' \
  "$VAULT_ADDR/v1/auth/token/revoke-accessor"
jq -c '.warnings' < /tmp/wwr
echo "A revocation script can run cleanly for months and revoke nothing."
B=$(vault token create -policy=default -type=batch -field=token)
printf '  and a batch token has no accessor at all: "%s"\n' \
  "$(vault token lookup -format=json "$B" 2>/dev/null | jq -r '.data.accessor // ""')"

wwr_done
