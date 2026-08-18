#!/usr/bin/env bash
# Chapter 23 - a total outage caused by a file permission.
#
# If audit devices are enabled and NONE can write, Vault refuses the
# request. Not a warning - a refusal. An unauditable Vault is considered
# worse than an unavailable one.
set -uo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first}"

echo "== disabling the syslog device so only one remains =="
vault audit disable syslog/ 2>/dev/null || true
vault audit list

echo
echo "== breaking the only device =="
docker compose exec -T vault chmod 000 /vault/logs/audit.log
echo -n "   write: "
vault kv put meridian/should-fail x=y 2>&1 | tail -1 | sed 's/^ *//'
echo -n "   read:  "
vault kv get meridian/audit-demo 2>&1 | tail -1 | sed 's/^ *//'
echo -n "   seal:  "
vault status | grep Sealed

echo
echo "Vault is running, unsealed and healthy - and refusing everything,"
echo "because it cannot record what it did. From the outside this looks"
echo "nothing like a Vault problem."

echo
echo "== fixing =="
docker compose exec -T vault chmod 644 /vault/logs/audit.log
vault kv put meridian/should-fail x=y >/dev/null && echo "   recovered, no restart"

echo
echo "== now with a second device, different failure mode =="
vault audit enable -path=syslog syslog tag="vault" >/dev/null 2>&1 || true
docker compose exec -T vault chmod 000 /vault/logs/audit.log
echo -n "   write: "
vault kv put meridian/still-works x=y >/dev/null 2>&1 \
  && echo "SUCCESS - one device persisted, which is all Vault requires"
docker compose exec -T vault chmod 644 /vault/logs/audit.log
