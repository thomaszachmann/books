#!/usr/bin/env bash
# Chapter 10 - every error the chapter prints, on purpose.
#
# Needs PostgreSQL from docker-compose.yml. Run setup-database.sh first,
# or at least 'docker compose up -d postgres'.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

PGHOST="${WWR_PGHOST:-postgres:5432}"
PSQL="${WWR_PSQL:-docker compose -f docker-compose.yml exec -T postgres psql}"
vault secrets enable database >/dev/null 2>&1 || true

wwr_case "failed to verify connection: lookup <host>: no such host"
echo "Inside Compose, containers reach each other by service name."
echo "Pointing Vault at a name that does not resolve:"
wwr_expect "no such host" vault write database/config/wwr-bad \
  plugin_name=postgresql-database-plugin \
  allowed_roles="*" \
  connection_url="postgresql://{{username}}:{{password}}@nosuchhost:5432/meridian?sslmode=disable" \
  username=postgres password=postgres-root

wwr_case "pq: password authentication failed"
wwr_expect "password authentication failed" vault write database/config/wwr-pw \
  plugin_name=postgresql-database-plugin allowed_roles="*" \
  connection_url="postgresql://{{username}}:{{password}}@$PGHOST/meridian?sslmode=disable" \
  username=postgres password=definitely-wrong
echo "After rotate-root, Vault holds the only copy - a configuration that"
echo "still supplies a password will break the connection in exactly this way."

wwr_case "permission denied to create role"
echo "An account without CREATEROLE cannot make what Vault asks for."
$PSQL -U postgres -d meridian -c \
  "DROP ROLE IF EXISTS wwr_weak;" >/dev/null 2>&1
$PSQL -U postgres -d meridian -c \
  "CREATE ROLE wwr_weak WITH LOGIN PASSWORD 'weak-pw';" >/dev/null 2>&1
vault write database/config/wwr-weak \
  plugin_name=postgresql-database-plugin allowed_roles="wwr-weak-role" \
  connection_url="postgresql://{{username}}:{{password}}@$PGHOST/meridian?sslmode=disable" \
  username=wwr_weak password=weak-pw >/dev/null
vault write database/roles/wwr-weak-role db_name=wwr-weak \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
  default_ttl=1h >/dev/null
wwr_expect "permission denied to create role" vault read database/creds/wwr-weak-role

wwr_case "\"<role>\" is not an allowed role"
vault write database/config/wwr-strict \
  plugin_name=postgresql-database-plugin allowed_roles="only-this-one" \
  connection_url="postgresql://{{username}}:{{password}}@$PGHOST/meridian?sslmode=disable" \
  username=postgres password=postgres-root >/dev/null
vault write database/roles/wwr-other db_name=wwr-strict \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
  default_ttl=1h >/dev/null
wwr_expect "is not an allowed role" vault read database/creds/wwr-other
echo "The control doing its job. allowed_roles is on the connection:"
vault read -field=allowed_roles database/config/wwr-strict | sed 's/^/  /'

wwr_case "the username is truncated"
echo "PostgreSQL identifiers stop at 63 characters. Vault's names are long:"
vault write database/roles/wwr-a-deliberately-very-long-role-name-for-this \
  db_name=wwr-strict \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
  default_ttl=1h >/dev/null 2>&1 || true
u=$(vault read -field=username database/creds/wwr-other 2>/dev/null || echo "")
[ -n "$u" ] && printf '  a generated username: %s  (%s chars)\n' "$u" "${#u}"
echo "Use username_template, or a shorter role name. Oracle at 30 is worse."

wwr_case "credentials work but the lease is gone"
# A revocation that cannot succeed, so the point is deterministic rather
# than dependent on timing. Pausing the database was the first attempt and
# proved nothing: Vault simply retried and the account went away.
vault write database/roles/wwr-orphan db_name=wwr-strict \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
  revocation_statements="DROP ROLE \"no_such_role_exists_here\";" \
  default_ttl=1h >/dev/null
vault write database/config/wwr-strict allowed_roles="only-this-one,wwr-ro,wwr-orphan" \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@$PGHOST/meridian?sslmode=disable" \
  username=postgres password=postgres-root >/dev/null

U=$(vault read -field=username database/creds/wwr-orphan)
printf '  created in postgres : %s\n' "$U"
exists() { $PSQL -U postgres -d meridian -tAc \
  "SELECT rolname FROM pg_roles WHERE rolname='$U';" 2>/dev/null | tr -d ' \n'; }
printf '  exists?             : %s\n' "$(exists)"

echo
echo "An honest revoke fails, because the revocation statement cannot run:"
vault lease revoke -prefix database/creds/wwr-orphan 2>&1 | sed -n '1,4p' | sed 's/^/  /'
printf '  account after the failed revoke: %s\n' "$(exists)"

echo
echo "Now with -force:"
vault lease revoke -force -prefix database/creds/wwr-orphan >/dev/null 2>&1
n=$(vault list -format=json sys/leases/lookup/database/creds/wwr-orphan 2>/dev/null \
      | jq 'length' 2>/dev/null); : "${n:=0}"
printf '  leases Vault still knows about : %s\n' "$n"
printf '  account in postgres            : %s\n' "$(exists)"
echo
echo "Vault has forgotten it. PostgreSQL has not. Nothing will ever clean"
echo "that account up, because the only system that knew it existed no"
echo "longer does. Audit for these by comparing pg_roles against the"
echo "leases, and fix the revocation statement rather than forcing."
$PSQL -U postgres -d meridian -c "DROP ROLE IF EXISTS \"$U\";" >/dev/null 2>&1
echo "  (tidied by hand, which is the only way)"

for c in wwr-bad wwr-pw wwr-weak wwr-strict; do
  vault delete database/config/$c >/dev/null 2>&1 || true
done
$PSQL -U postgres -d meridian -c "DROP ROLE IF EXISTS wwr_weak;" >/dev/null 2>&1
wwr_done
