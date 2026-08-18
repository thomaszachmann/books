#!/usr/bin/env bash
# Chapter 14 - an AppRole for wrapped SecretID delivery.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

vault kv put meridian/tracking \
  db_user=tracking_svc db_password=wrap-lab-pw >/dev/null

vault policy write tracking-read chapters/ch14/policies/tracking-read.hcl
vault auth enable approle 2>/dev/null || true

vault write auth/approle/role/tracking \
  token_policies="tracking-read" \
  token_ttl=1h token_max_ttl=4h \
  secret_id_ttl=10m secret_id_num_uses=1 >/dev/null

echo "Ready."
echo
echo "  ./chapters/ch14/deliver-secret-id.sh"
echo "  ./chapters/ch14/consume-secret-id.sh <wrapping-token>"
