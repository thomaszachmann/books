#!/usr/bin/env bash
# Chapter 15 - AppRole, policy and credential files for the agent.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

vault kv put meridian/tracking \
  db_user=tracking_svc db_password=agent-lab-pw >/dev/null

vault policy write agent-tracking \
  chapters/ch15/policies/agent-tracking.hcl 2>/dev/null \
  || vault policy write agent-tracking - <<'POL'
path "meridian/data/tracking" {
  capabilities = ["read"]
}
POL

vault auth enable approle 2>/dev/null || true

# Short lifetimes on purpose: renewal and re-auth happen in minutes,
# not hours, so you can watch them in the log.
vault write auth/approle/role/agent \
  token_policies="agent-tracking" \
  token_ttl=1m token_max_ttl=3m secret_id_ttl=10m >/dev/null

D=chapters/ch15/agent
vault read -field=role_id auth/approle/role/agent/role-id > "$D/role-id"
vault write -f -field=secret_id \
  auth/approle/role/agent/secret-id > "$D/secret-id"
chmod 600 "$D/secret-id"

echo "Ready. Start the agent:"
echo "  cd $D && vault agent -config=agent.hcl -log-level=info"
