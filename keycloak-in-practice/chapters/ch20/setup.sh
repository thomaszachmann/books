#!/usr/bin/env bash
# The machine edge, made real. Chapter 20, Step 2.
#
# After this, Keycloak cannot start without Vault:
#   - an AppRole `keycloak` whose policy reads one thing, the static
#     database credential from Chapter 19
#   - its role id and secret id in vault/approle/ (git-ignored)
#   - chapters/ch20/compose.yaml added to the stack through .env:
#     vault-agent logs in and renders the credential, and Keycloak
#     starts through kc-start.sh, which refuses to start without it
#
# Expects Chapter 19's setup.sh to have run.
set -euo pipefail

cd "$(dirname "$0")/../.."
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root
v() { docker compose exec -T -e VAULT_ADDR -e VAULT_TOKEN vault vault "$@"; }

echo "policy keycloak-db - one path, read only"
v policy write keycloak-db - <<'HCL'
path "database/static-creds/keycloak-static" {
  capabilities = ["read"]
}
HCL

echo "approle keycloak"
v auth enable approle 2>/dev/null || echo "  enabled"
# secret_id_ttl=0: the secret id does not expire. Chapter 20's
# break-it section is about what happens when it does.
v write auth/approle/role/keycloak \
  token_policies=keycloak-db token_ttl=20m token_max_ttl=1h \
  secret_id_ttl=0

mkdir -p vault/approle
chmod 700 vault/approle
umask 077
v read -field=role_id auth/approle/role/keycloak/role-id \
  > vault/approle/role_id
v write -f -field=secret_id auth/approle/role/keycloak/secret-id \
  > vault/approle/secret_id
echo "  vault/approle/role_id and secret_id written (mode 600)"

LINE=COMPOSE_FILE=compose.yaml:chapters/ch20/compose.yaml
grep -qx "$LINE" .env || echo "$LINE" >> .env
echo "  .env: $LINE"

echo "vault-agent, then Keycloak through kc-start.sh"
docker compose up -d vault-agent
docker compose up -d --no-deps keycloak

cat <<'NEXT'

Done. Keycloak's container was recreated, which forgets the admin CLI's
login and trust store: run `make kcadm-init` again before using kcadm.

Keycloak now reads its database user from Vault at every start:

  docker compose logs keycloak | grep kc-start
  kc-start: database user keycloak_app, from Vault

To undo: delete the COMPOSE_FILE line from .env, then
  docker compose up -d --no-deps keycloak
  docker compose rm -sf vault-agent
NEXT
