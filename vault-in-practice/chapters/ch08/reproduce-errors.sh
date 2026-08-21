#!/usr/bin/env bash
# Chapter 8 - every error the chapter prints, on purpose.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env
command -v jq >/dev/null || { echo "jq required - see Appendix A"; exit 1; }

vault auth enable -path=wwr-a userpass >/dev/null 2>&1 || true
vault auth enable -path=wwr-b userpass >/dev/null 2>&1 || true
ACC_A=$(vault auth list -format=json | jq -r '.["wwr-a/"].accessor')
ACC_B=$(vault auth list -format=json | jq -r '.["wwr-b/"].accessor')
vault write auth/wwr-a/users/alice password=lab-a policies=default >/dev/null
vault write auth/wwr-b/users/a.smith password=lab-b policies=default >/dev/null
EID=$(vault read -field=id identity/entity/name/wwr-person 2>/dev/null || \
      vault write -format=json identity/entity name=wwr-person | jq -r .data.id)

wwr_case "entity already has an alias for this mount accessor"
vault write identity/entity-alias name=alice \
  canonical_id="$EID" mount_accessor="$ACC_A" >/dev/null
echo "One alias per mount is the rule. A second on the same mount:"
wwr_expect "Alias already exists" vault write identity/entity-alias \
  name=someone-else canonical_id="$EID" mount_accessor="$ACC_A"

wwr_case "the alias exists but the entity ID does not change at login"
echo "The alias name must be the username as that method sees it."
vault write identity/entity-alias name=WRONG-NAME \
  canonical_id="$EID" mount_accessor="$ACC_B" >/dev/null
T=$(VAULT_TOKEN='' vault login -field=token -method=userpass -path=wwr-b \
      username=a.smith password=lab-b)
got=$(VAULT_TOKEN=$T vault token lookup -format=json | jq -r .data.entity_id)
if [ "$got" = "$EID" ]; then echo "   unexpectedly matched"; else
  printf '  entity we built : %s\n  entity at login : %s\n' "$EID" "$got"
  echo "   ok: different, because the alias name does not match the username"
fi
echo "What Vault actually recorded:"
vault read -format=json identity/entity/id/"$EID" \
  | jq -r '.data.aliases[] | "  alias \(.name) on \(.mount_path)"'

wwr_case "invalid mount accessor"
echo "A mount path where an accessor is required:"
wwr_expect "invalid mount accessor" vault write identity/entity-alias \
  name=alice canonical_id="$EID" mount_accessor="wwr-a/"
printf '  the accessor looks like this: %s\n' "$ACC_A"

wwr_case "removing somebody from a group has no effect"
vault policy write wwr-grouppol - >/dev/null <<'POL'
path "secret/data/oncall/*" { capabilities = ["read"] }
POL
GID=$(vault write -format=json identity/group name=wwr-group \
        policies=wwr-grouppol member_entity_ids="$EID" | jq -r .data.id)
vault write identity/entity-alias name=alice \
  canonical_id="$EID" mount_accessor="$ACC_A" >/dev/null 2>&1 || true
T=$(VAULT_TOKEN='' vault login -field=token -method=userpass -path=wwr-a \
      username=alice password=lab-a)
echo "while a member - note WHICH field carries the group policy:"
VAULT_TOKEN=$T vault token lookup -format=json \
  | jq -c '{policies:.data.policies, identity_policies:.data.identity_policies}'
printf '  may read secret/data/oncall/x : %s\n' \
  "$(vault token capabilities "$T" secret/data/oncall/x)"
vault write identity/group id="$GID" name=wwr-group \
  policies=wwr-grouppol member_entity_ids="" >/dev/null
echo "removed from the group - the SAME token, no new login:"
VAULT_TOKEN=$T vault token lookup -format=json \
  | jq -c '{policies:.data.policies, identity_policies:.data.identity_policies}'
printf '  may read secret/data/oncall/x : %s\n' \
  "$(vault token capabilities "$T" secret/data/oncall/x)"
echo
echo "It took effect at once. Vault resolves a token's permissions on"
echo "every request; it does not stamp them in at login. Only what Vault"
echo "learns FROM a directory - an external group's membership - waits"
echo "for the next login, because Vault cannot see the directory."

wwr_case "disabling an entity and existing tokens"
echo "The chapter's lab disables an entity to close both logins."
echo "It also invalidates the tokens already issued:"
printf '  lookup before : %s\n' \
  "$(VAULT_TOKEN=$T vault token lookup >/dev/null 2>&1 && echo works || echo refused)"
vault write identity/entity/id/"$EID" disabled=true >/dev/null
printf '  lookup after  : %s\n' \
  "$(VAULT_TOKEN=$T vault token lookup >/dev/null 2>&1 && echo works || echo refused)"
VAULT_TOKEN=$T vault token lookup 2>&1 | grep -E "invalid token|permission denied" | head -2
vault write identity/entity/id/"$EID" disabled=false >/dev/null
echo "Leases are the exception: a database credential already issued"
echo "lives in PostgreSQL, not in Vault, and keeps working until revoked."

wwr_case "two entities exist for the same person"
echo "Vault creates one automatically for an unknown identity at login."
vault write auth/wwr-b/users/stray password=lab-c policies=default >/dev/null
VAULT_TOKEN='' vault login -method=userpass -path=wwr-b \
  username=stray password=lab-c >/dev/null
n=$(vault list -format=json identity/entity/id | jq 'length')
printf '  entities now: %s\n' "$n"
echo "Merge them with identity/entity/merge - aliases and metadata move."

vault delete identity/group/id/"$GID" >/dev/null 2>&1 || true
vault delete identity/entity/id/"$EID" >/dev/null 2>&1 || true
vault policy delete wwr-grouppol >/dev/null 2>&1 || true
vault auth disable wwr-a >/dev/null 2>&1 || true
vault auth disable wwr-b >/dev/null 2>&1 || true
wwr_done
