#!/usr/bin/env bash
# Chapter 19 - the TOTP engine. Runs with no external dependency at all.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first}"

vault secrets enable totp 2>/dev/null || true
vault write totp/keys/meridian generate=true \
  issuer=Meridian account_name=priya@meridian.example >/dev/null

echo "code now: $(vault read -field=code totp/code/meridian)"
CODE=$(vault read -field=code totp/code/meridian)
echo -n "validating it: "
vault write -field=valid totp/code/meridian code="$CODE"
echo "waiting for the window to roll over..."
sleep 31
echo "code now: $(vault read -field=code totp/code/meridian)"
