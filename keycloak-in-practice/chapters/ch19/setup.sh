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

# Every user Vault hands to Keycloak is made a member of the role that
# owns Keycloak's tables. A login role with only database and schema
# rights cannot read a single table, and Keycloak's first query at
# start fails with "permission denied for table databasechangelog".
# Membership carries the owner's rights, including the ones a schema
# migration needs (Chapter 23).
echo "dynamic role - a new user per lease"
v write database/roles/keycloak-dynamic \
  db_name=keycloak \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT \"$DB_USER\" TO \"{{name}}\";" \
  default_ttl=5m max_ttl=1h

# The static role gets a user of its own. Vault rotates its password the
# moment the role is created, and from then on only Vault knows it. Had
# it been $DB_USER, the password in .env - which Vault itself, backup.sh
# and rehearse.sh log in with - would stop working without a word.
echo "keycloak_app - the user the static role owns"
docker compose exec -T db psql -q -U "$DB_USER" -d keycloak <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'keycloak_app') THEN
    CREATE ROLE keycloak_app LOGIN;
  END IF;
END \$\$;
GRANT "$DB_USER" TO keycloak_app;
SQL

echo "static role - one user, rotated on a schedule"
v write database/static-roles/keycloak-static \
  db_name=keycloak \
  username=keycloak_app \
  rotation_period=24h

echo "pki engine"
v secrets enable pki 2>/dev/null || echo "  enabled"
v secrets tune -max-lease-ttl=8760h pki
v write pki/root/generate/internal \
  common_name="Meridian Vault Issuing CA" ttl=8760h >/dev/null
v write pki/roles/meridian \
  allowed_domains=meridian.test \
  allow_subdomains=true max_ttl=72h >/dev/null

cat <<'NEXT'

Ready. Two ways to get a database credential:

  vault read database/creds/keycloak-dynamic    a new user, 5m lease
  vault read database/static-creds/keycloak-static   keycloak_app, always

The chapter uses the first to demonstrate the problem and the second to
live with it. Which one is right depends on whether the consumer can be
told that its credential changed - and Keycloak cannot.
NEXT
