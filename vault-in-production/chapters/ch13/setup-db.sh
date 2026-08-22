#!/usr/bin/env bash
# Postgres plus a database secrets engine with two roles that
# differ by four words. Run after `make up && make init && make
# unseal`, with ./scripts/vault-env.sh sourced.
set -euo pipefail

NET=${NET:-vault-in-production_default}
PGIMG=${PGIMG:-docker.io/library/postgres:16-alpine}
ENGINE=${ENGINE:-docker}

$ENGINE rm -f blast-db pgclient >/dev/null 2>&1 || true
$ENGINE run -d --name blast-db --network "$NET" \
  -e POSTGRES_PASSWORD=rootpw -e POSTGRES_DB=appdb "$PGIMG" >/dev/null
# a SEPARATE client: psql -h 127.0.0.1 inside blast-db hits a
# `trust` line in pg_hba.conf and accepts any password at all
$ENGINE run -d --name pgclient --network "$NET" "$PGIMG" \
  sleep 86400 >/dev/null

until $ENGINE exec blast-db pg_isready -q 2>/dev/null; do sleep 2; done

vault secrets enable database 2>/dev/null || true
vault write database/config/appdb \
  plugin_name=postgresql-database-plugin \
  allowed_roles="app,app-noexp" \
  connection_url="postgresql://{{username}}:{{password}}@blast-db:5432/appdb?sslmode=disable" \
  username=postgres password=rootpw >/dev/null

# WITH an expiry clause: Postgres enforces it even when Vault
# is down.
vault write database/roles/app db_name=appdb \
  default_ttl=1m max_ttl=5m \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  >/dev/null

# WITHOUT it: nothing expires this credential except a Vault
# that is, by assumption, unavailable.
vault write database/roles/app-noexp db_name=appdb \
  default_ttl=1m max_ttl=5m \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  >/dev/null

echo "ready: roles app (expires) and app-noexp (does not)"
