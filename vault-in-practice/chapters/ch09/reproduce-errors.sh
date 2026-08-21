#!/usr/bin/env bash
# Chapter 9 - every error the chapter prints, on purpose.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

vault secrets enable -path=wwr2 -version=2 kv >/dev/null 2>&1 || true
vault secrets enable -path=wwr1 -version=1 kv >/dev/null 2>&1 || true

wwr_case "a field disappeared after an update"
vault kv put wwr2/app db_user=svc db_password=first >/dev/null
echo "the secret has two fields:"
vault kv get -format=json wwr2/app | jq -c .data.data
echo '$ vault kv put wwr2/app db_password=second      # put, not patch'
vault kv put wwr2/app db_password=second >/dev/null
vault kv get -format=json wwr2/app | jq -c .data.data
echo "db_user is gone. put replaces the whole secret; patch merges."
echo "Recover from the previous version:"
vault kv rollback -version=1 wwr2/app >/dev/null
vault kv get -format=json wwr2/app | jq -c .data.data

wwr_case "check-and-set parameter required for this call"
vault kv metadata put -cas-required=true wwr2/app >/dev/null
wwr_expect "check-and-set parameter required" vault kv put wwr2/app x=y
echo "Read the current version, then supply it:"
v=$(vault kv get -format=json wwr2/app | jq -r .data.metadata.version)
vault kv put -cas="$v" wwr2/app db_user=svc db_password=third >/dev/null \
  && echo "   ok: write with -cas=$v accepted"

wwr_case "check-and-set parameter did not match the current version"
echo "Somebody wrote between your read and your write:"
wwr_expect "did not match the current version" vault kv put -cas=1 wwr2/app x=y
vault kv metadata put -cas-required=false wwr2/app >/dev/null

wwr_case "No value found at <path>"
echo "The message means the path was NEVER written:"
wwr_expect "No value found" vault kv get wwr2/never-existed
echo
echo "A deleted secret does not produce it. It returns metadata instead:"
vault kv put wwr2/gone a=b >/dev/null
vault kv delete wwr2/gone >/dev/null
vault kv get wwr2/gone 2>&1 | grep -E "deletion_time|destroyed|version " | sed 's/^/  /'
echo "and a destroyed one says so in the same place:"
vault kv put wwr2/dead a=b >/dev/null
vault kv destroy -versions=1 wwr2/dead >/dev/null
vault kv get wwr2/dead 2>&1 | grep -E "deletion_time|destroyed" | sed 's/^/  /'
echo
echo "So when you DO get 'No value found', look at the path, not the"
echo "history. Wrong mount, or version 1 syntax against a version 2 mount:"
vault kv put wwr1/app a=b >/dev/null
wwr_run vault kv get -version=2 wwr1/app

wwr_case "KV engine mount must be version 2 for patch support"
echo "A version 1 mount has no patch:"
wwr_expect "must be version 2 for patch support" vault kv patch wwr1/app c=d

wwr_case "old versions vanished without warning"
vault kv metadata put -max-versions=3 wwr2/churn >/dev/null
for i in 1 2 3 4 5; do vault kv put wwr2/churn n=$i >/dev/null; done
echo "five writes, max-versions is 3:"
vault kv metadata get -format=json wwr2/churn \
  | jq -c '{current: .data.current_version, kept: (.data.versions | keys)}'
echo "Pruning is silent by design. The default is 10."
wwr_expect "No value found" vault kv get -version=1 wwr2/churn

wwr_case "vault kv get -version=2 returns nothing on a version 1 mount"
echo "Version 1 has no versions. The flag is accepted and meaningless:"
vault kv get -version=2 wwr1/app 2>&1 | sed -n '1,6p' | grep -v '^$'

vault secrets disable wwr2 >/dev/null 2>&1 || true
vault secrets disable wwr1 >/dev/null 2>&1 || true
wwr_done
