#!/usr/bin/env bash
# Chapter 14 - every error the chapter prints, on purpose.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env
ROOT="$VAULT_TOKEN"

vault secrets enable -path=wwr14 -version=2 kv >/dev/null 2>&1 || true
vault kv put wwr14/tracking db_user=svc db_password=lab >/dev/null

wwr_case "wrapping token is not valid or does not exist"
echo "Cause 1 of 4: already unwrapped."
WT=$(vault kv get -wrap-ttl=120s -field=wrapping_token wwr14/tracking)
vault unwrap "$WT" >/dev/null && echo "   first unwrap: ok"
wwr_expect "does not exist" vault unwrap "$WT"
echo
echo "Cause 2: the TTL expired."
WT=$(vault kv get -wrap-ttl=1s -field=wrapping_token wwr14/tracking)
sleep 2
wwr_expect "does not exist" vault unwrap "$WT"
echo
echo "Cause 3: it was rewrapped, which invalidates the original."
WT=$(vault kv get -wrap-ttl=120s -field=wrapping_token wwr14/tracking)
NEW=$(vault write -field=token sys/wrapping/rewrap token="$WT")
vault unwrap "$NEW" >/dev/null && echo "   the new token works"
wwr_expect "does not exist" vault unwrap "$WT"
echo
echo "Cause 4: mistyped. Same text again:"
wwr_expect "does not exist" vault unwrap "hvs.notarealwrappingtoken"
echo
echo "Four causes, one message. The audit log is what separates them -"
echo "it records the unwrap with a timestamp and a source address."
echo "If your application reports this and you did not expect it, treat"
echo "the secret as compromised and reissue. That is cheap."

wwr_case "vault unwrap returns nothing useful"
WT=$(vault kv get -wrap-ttl=120s -field=wrapping_token wwr14/tracking)
echo "Look before you redeem - lookup does not consume the token:"
vault write -format=json sys/wrapping/lookup token="$WT" \
  | jq -c '{creation_path:.data.creation_path, creation_ttl:.data.creation_ttl}'
echo "creation_path names the endpoint whose response is inside."
vault unwrap "$WT" >/dev/null && echo "   and the token still worked afterwards"

wwr_case "the cubbyhole is empty for a token you know wrote to it"
A=$(vault token create -policy=default -field=token)
VAULT_TOKEN=$A vault write cubbyhole/note text=hello >/dev/null
echo "the token that wrote it can read it:"
VAULT_TOKEN=$A vault read -field=text cubbyhole/note | sed 's/^/  /'
echo "root cannot - there is no path that reads somebody else's:"
VAULT_TOKEN=$ROOT wwr_expect "No value found" vault read cubbyhole/note

wwr_case "error validating wrapping token: token is empty"
echo "Genuinely no token anywhere - note that VAULT_TOKEN='' is not"
echo "enough, because ~/.vault-token takes over. Chapter 4's precedence"
echo "rule, met again where it is easy to miss:"
EMPTY=$(mktemp -d)
VAULT_TOKEN='' HOME="$EMPTY" wwr_expect "token is empty" vault unwrap
echo
echo "With a token file present, the same command says something else,"
echo "because a token WAS sent - just not a wrapping one:"
VAULT_TOKEN='' wwr_expect "wrapping token is not valid" vault unwrap
rmdir "$EMPTY" 2>/dev/null || true

wwr_case "everything is suddenly wrapped"
echo "VAULT_WRAP_TTL is still exported from an earlier command:"
out=$(VAULT_WRAP_TTL=60s vault kv get -format=json wwr14/tracking)
printf '%s' "$out" | jq -c '{data:.data, wrap_info:(.wrap_info|{token:(.token[0:12]+"..."), ttl})}'
echo "The response is a wrapping token instead of the secret. unset it:"
echo '  $ unset VAULT_WRAP_TTL'

wwr_case "the wrapping token expired before the application started"
echo "The TTL is delivery time, not application lifetime:"
WT=$(vault kv get -wrap-ttl=2s -field=wrapping_token wwr14/tracking)
echo "  a pod that takes 3 seconds to schedule..."
sleep 3
wwr_expect "does not exist" vault unwrap "$WT"
echo "Measure the delivery path rather than guessing. A token that"
echo "routinely expires trains people to ignore the alarm."

vault secrets disable wwr14 >/dev/null 2>&1 || true
wwr_done
