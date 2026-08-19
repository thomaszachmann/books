#!/usr/bin/env bash
# Chapter 8 - one person, two logins, one identity.
#
# Two userpass mounts stand in for userpass and OIDC. The mechanism is
# identical and this needs no identity provider.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"
command -v jq >/dev/null || { echo "jq is required - see Appendix A"; exit 1; }

# Step 1 - two auth mounts, and the accessors that bind aliases to them.
vault auth enable -path=login-a userpass 2>/dev/null || echo "login-a already enabled"
vault auth enable -path=login-b userpass 2>/dev/null || echo "login-b already enabled"

ACC_A=$(vault auth list -format=json | jq -r '.["login-a/"].accessor')
ACC_B=$(vault auth list -format=json | jq -r '.["login-b/"].accessor')

# Step 2 - deliberately different usernames, as a real person would have.
vault write auth/login-a/users/alice      password=lab-a policies=default >/dev/null
vault write auth/login-b/users/p.raghavan password=lab-b policies=default >/dev/null

# Step 3 - data and policies to test with.
vault secrets enable -path=meridian -version=2 kv >/dev/null 2>&1 || true
vault kv put meridian/personal/alice note=entity-level >/dev/null
vault kv put meridian/oncall/runbook note=group-level  >/dev/null

vault policy write entity-alice   chapters/ch08/policies/entity-alice.hcl
vault policy write group-oncall   chapters/ch08/policies/group-oncall.hcl
vault policy write personal-space chapters/ch08/policies/personal-space.hcl

# Step 5 - one entity, both logins attached to it.
EID=$(vault read -field=id identity/entity/name/alice 2>/dev/null || true)
if [ -z "$EID" ]; then
  EID=$(vault write -format=json identity/entity \
          name="alice" \
          policies="entity-alice" \
          metadata=team="platform" | jq -r '.data.id')
fi

# The alias name is the username as THAT method knows it - hence the two.
vault write identity/entity-alias name="alice" \
  canonical_id="$EID" mount_accessor="$ACC_A" >/dev/null
vault write identity/entity-alias name="p.raghavan" \
  canonical_id="$EID" mount_accessor="$ACC_B" >/dev/null

# Step 6 - a group, carrying its own policy.
vault write identity/group name="platform" \
  policies="group-oncall" member_entity_ids="$EID" >/dev/null

echo
echo "Entity: $EID"
echo "  login-a accessor: $ACC_A"
echo "  login-b accessor: $ACC_B"
echo
echo "Ready. Prove it - both logins, same entity_id, same three policies:"
echo
echo "  ROOT=\$VAULT_TOKEN; unset VAULT_TOKEN"
echo "  vault login -method=userpass -path=login-a username=alice password=lab-a"
echo "  vault token lookup -format=json | jq '{entity_id, policies}'"
echo "  vault login -method=userpass -path=login-b username=p.raghavan password=lab-b"
echo "  vault token lookup -format=json | jq '{entity_id, policies}'"
echo "  vault kv get meridian/personal/alice"
echo "  vault kv get meridian/oncall/runbook"
echo "  export VAULT_TOKEN=\$ROOT"
echo
echo "Then the two drills:"
echo "  ./chapters/ch08/revoke-drill.sh     # one flag closes both doors"
echo "  ./chapters/ch08/templated-policy.sh # one policy, every entity"
