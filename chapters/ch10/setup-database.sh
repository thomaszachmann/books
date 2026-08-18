#!/usr/bin/env bash
# Chapter 10 - PostgreSQL plus the database secrets engine.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

docker compose -f lab/docker-compose.yml up -d postgres
sleep 5

PSQL="docker compose -f lab/docker-compose.yml exec -T postgres psql"

$PSQL -U postgres -d meridian -c \
  "CREATE TABLE IF NOT EXISTS shipments (id int, dest text);"
$PSQL -U postgres -d meridian -c \
  "INSERT INTO shipments VALUES (1, 'Hamburg');"
$PSQL -U postgres -d meridian -c \
  "DROP ROLE IF EXISTS vaultadmin;"
$PSQL -U postgres -d meridian -c \
  "CREATE ROLE vaultadmin WITH LOGIN SUPERUSER PASSWORD 'bootstrap-only';"

vault secrets enable database 2>/dev/null || true

PGTARGET="postgres:5432/meridian?sslmode=disable"
CONN="postgresql://{{username}}:{{password}}@$PGTARGET"

vault write database/config/meridian-pg \
  plugin_name=postgresql-database-plugin \
  allowed_roles="tracking-ro,tracking-rw" \
  connection_url="$CONN" \
  username="vaultadmin" \
  password="bootstrap-only"

CREATE_RO="CREATE ROLE \"{{name}}\" WITH LOGIN
  PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"

REVOKE_SQL="REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
  FROM \"{{name}}\";
  DROP ROLE IF EXISTS \"{{name}}\";"

vault write database/roles/tracking-ro \
  db_name=meridian-pg \
  creation_statements="$CREATE_RO" \
  revocation_statements="$REVOKE_SQL" \
  default_ttl="2m" max_ttl="10m"

echo
echo "Done. Now take the root password away from yourself:"
echo "  vault write -f database/rotate-root/meridian-pg"
echo
echo "Then:  vault read database/creds/tracking-ro"
