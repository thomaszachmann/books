#!/usr/bin/env bash
# Chapter 23 - two audit devices with different failure modes.
#
# Two file devices on one filesystem are one device wearing two hats.
# The question to ask of any pair: what single event takes both out?
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

vault audit enable file file_path=/vault/logs/audit.log 2>/dev/null \
  || echo "file device already enabled"
vault audit enable -path=syslog syslog tag="vault" facility="AUTH" \
  2>/dev/null || echo "syslog device already enabled"

vault audit list -detailed

vault kv put meridian/audit-demo password=SuperSecret123 >/dev/null

echo
echo "== the secret is NOT in the log =="
echo -n "   grep hits: "; grep -c 'SuperSecret123' logs/audit.log || true

echo "== but it is provably present =="
H=$(vault write -field=hash sys/audit-hash/file input="SuperSecret123")
echo "   hash: ${H:0:32}..."
echo -n "   entries: "; grep -c "$H" logs/audit.log || true
echo
echo "Two entries - the request and the response. Not readable,"
echo "provably present. That is what makes a log evidence."
