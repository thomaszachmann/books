#!/usr/bin/env bash
# Keycloak authenticates Vault. Chapter 18.
#
# Two auth methods for two populations, on one identity provider:
#   oidc  humans, with a browser
#   jwt   machines, with a token they already hold
#
# Both validate against the same issuer and the same keys. The
# difference is only who runs the flow.
set -euo pipefail

cd "$(dirname "$0")/../.."
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root
v() { docker compose exec -T -e VAULT_ADDR -e VAULT_TOKEN vault vault "$@"; }
kc() { docker compose exec -T keycloak /opt/keycloak/bin/kcadm.sh "$@"; }

ISS=https://sso.meridian.test/realms/meridian
CA=/etc/ssl/certs/meridian-ca.pem

echo "policy"
v policy write shipments - <<'HCL'
path "secret/data/shipments/*" {
  capabilities = ["read", "list"]
}
HCL

echo "oidc auth method"
v auth enable oidc 2>/dev/null || echo "  enabled"
v write auth/oidc/config \
  oidc_discovery_url="$ISS" \
  oidc_discovery_ca_pem=@"$CA" \
  oidc_client_id=vault \
  oidc_client_secret=vault-secret-change-me \
  default_role=dispatcher

v write auth/oidc/role/dispatcher \
  bound_audiences=vault \
  allowed_redirect_uris=http://localhost:8250/oidc/callback \
  allowed_redirect_uris=http://localhost:8200/ui/vault/auth/oidc/oidc/callback \
  user_claim=preferred_username \
  groups_claim=groups \
  oidc_scopes=openid,groups \
  policies=default \
  ttl=1h

echo "external group, so the policy follows the directory"
ACC=$(v auth list -format=json | \
      docker compose exec -T client jq -r '."oidc/".accessor')
GID=$(v write -format=json identity/group name=logistics \
        type=external policies=shipments | \
      docker compose exec -T client jq -r .data.id)
v write identity/group-alias name=logistics \
  mount_accessor="$ACC" canonical_id="$GID"

echo "jwt auth method, for machines"
v auth enable jwt 2>/dev/null || echo "  enabled"
v write auth/jwt/config \
  oidc_discovery_url="$ISS" \
  oidc_discovery_ca_pem=@"$CA"

v write auth/jwt/role/batch \
  role_type=jwt \
  bound_audiences=vault \
  bound_claims='{"azp":"meridian-batch"}' \
  user_claim=sub \
  policies=shipments \
  ttl=15m

cat <<'NEXT'

Ready.
  humans    vault login -method=oidc
  machines  vault write auth/jwt/login role=batch jwt=<token>

The audience is "vault" in both roles. Chapter 8's mapper is what puts
it there; without it the token says "account" and Vault refuses it with
a message about audiences that is, for once, accurate.
NEXT
