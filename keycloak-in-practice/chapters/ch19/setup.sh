#!/usr/bin/env bash
# Vault supplies Keycloak. Chapter 19.
#
# Three things move out of files and into Vault:
#   the database credential   dynamic, leased, revocable
#   the TLS certificate       issued by Vault's PKI engine
#   the client secrets        static, but versioned and audited
#
# The first one is where the interesting problem is, and this script
# sets up both shapes of it so the chapter can compare them.
set -euo pipefail

cd "$(dirname "$0")/../.."
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=root
v() { docker compose exec -T -e VAULT_ADDR -e VAULT_TOKEN vault vault "$@"; }

DB_USER=$(grep '^POSTGRES_USER=' .env | cut -d= -f2)
DB_PASS=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2)

echo "database secrets engine"
v secrets enable database 2>/dev/null || echo "  enabled"
v write database/config/keycloak \
  plugin_name=postgresql-database-plugin \
  allowed_roles="keycloak-dynamic,keycloak-static" \
  connection_url="postgresql://{{username}}:{{password}}@db:5432/keycloak?sslmode=disable" \
  username="$DB_USER" password="$DB_PASS"

echo "dynamic role - a new user per lease"
v write database/roles/keycloak-dynamic \
  db_name=keycloak \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON DATABASE keycloak TO \"{{name}}\"; GRANT ALL ON SCHEMA public TO \"{{name}}\";" \
  default_ttl=5m max_ttl=1h

echo "static role - one user, rotated on a schedule"
v write database/static-roles/keycloak-static \
  db_name=keycloak \
  username="$DB_USER" \
  rotation_period=24h

echo "pki engine"
v secrets enable pki 2>/dev/null || echo "  enabled"
v secrets tune -max-lease-ttl=8760h pki
v write pki/root/generate/internal \
  common_name="Meridian Vault Issuing CA" ttl=8760h >/dev/null
v write pki/roles/meridian \
  allowed_domains=meridian.test \
  allow_subdomains=true max_ttl=72h

cat <<'NEXT'

Ready. Two ways to get a database credential:

  vault read database/creds/keycloak-dynamic    a new user, 5m lease
  vault read database/static-creds/keycloak-static   the same user

The chapter uses the first to demonstrate the problem and the second to
live with it. Which one is right depends on whether the consumer can be
told that its credential changed - and Keycloak cannot.
NEXT
