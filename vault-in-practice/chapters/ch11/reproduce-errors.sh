#!/usr/bin/env bash
# Chapter 11 - every error the chapter prints, on purpose.
# Needs PostgreSQL from docker-compose.yml.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

PGHOST="${WWR_PGHOST:-postgres:5432}"
vault secrets enable database >/dev/null 2>&1 || true
vault write database/config/wwr11 \
  plugin_name=postgresql-database-plugin allowed_roles="wwr11-ro" \
  connection_url="postgresql://{{username}}:{{password}}@$PGHOST/meridian?sslmode=disable" \
  username=postgres password=postgres-root >/dev/null
vault write database/roles/wwr11-ro db_name=wwr11 \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
  default_ttl=20s max_ttl=45s >/dev/null

wwr_case "lease not found"
L=$(vault read -field=lease_id database/creds/wwr11-ro)
vault lease revoke "$L" >/dev/null 2>&1
echo "The lease was revoked. Renewing it now:"
wwr_expect "lease not found" vault lease renew "$L"
echo "There is nothing to extend. Reissue instead."

wwr_case "renewal succeeds but the credential stops working anyway"
echo "default_ttl is 20s, max_ttl is 45s. Renew every twelve seconds and"
echo "watch what the response actually grants - this takes about a minute:"
L=$(vault read -field=lease_id database/creds/wwr11-ro)
for i in 1 2 3 4; do
  sleep 12
  d=$(vault lease renew -format=json "$L" 2>/dev/null | jq -r .lease_duration)
  printf '  after %2ss, renewal %s granted: %s s\n' "$((i*12))" "$i" "${d:-refused}"
done
echo "It shrinks as max_ttl approaches. A loop that renews every 25"
echo "seconds and assumes it got 30 will fall behind and then fail."
vault lease revoke "$L" >/dev/null 2>&1

wwr_case "vault lease revoke -prefix removes nothing"
L=$(vault read -field=lease_id database/creds/wwr11-ro)
echo "A prefix that is not how lease IDs begin:"
vault lease revoke -prefix wwr11-ro 2>&1 | sed -n '1,2p' | sed 's/^/  /'
printf '  leases still outstanding: %s\n' \
  "$(vault list -format=json sys/leases/lookup/database/creds/wwr11-ro 2>/dev/null | jq 'length')"
echo "Lease IDs begin with the request path, so the prefix must too:"
printf '  the real ID: %s\n' "$L"
vault lease revoke -prefix database/creds/wwr11-ro >/dev/null 2>&1
printf '  after the right prefix:   %s\n' \
  "$(vault list -format=json sys/leases/lookup/database/creds/wwr11-ro 2>/dev/null | jq 'length' || echo 0)"

wwr_case "lease count grows without limit"
echo "Something asks for a credential in a loop and never releases one:"
for i in 1 2 3 4 5; do vault read -field=lease_id database/creds/wwr11-ro >/dev/null; done
printf '  after five requests: %s outstanding\n' \
  "$(vault list -format=json sys/leases/lookup/database/creds/wwr11-ro | jq 'length')"
echo "Find the source before raising any TTL. The fix is in the"
echo "application: obtain a credential and reuse it for its lifetime."
vault lease revoke -prefix database/creds/wwr11-ro >/dev/null 2>&1

wwr_case "vault lease renew on a token lease does nothing useful"
T=$(vault token create -policy=default -ttl=1h -field=token)
A=$(vault token lookup -format=json "$T" | jq -r .data.accessor)
echo "A token is not a lease you renew with lease renew:"
wwr_run vault lease renew "auth/token/create/$A"
echo "Tokens have their own command:"
vault token renew -format=json "$T" | jq -r '"  vault token renew -> \(.auth.lease_duration) s"'

vault delete database/roles/wwr11-ro >/dev/null 2>&1 || true
vault delete database/config/wwr11 >/dev/null 2>&1 || true
wwr_done
