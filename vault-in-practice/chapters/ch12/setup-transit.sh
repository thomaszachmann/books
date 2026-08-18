#!/usr/bin/env bash
# Chapter 12 - transit engine and keys.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

vault secrets enable transit 2>/dev/null || echo "transit already enabled"

vault write -f transit/keys/orders >/dev/null
vault write transit/keys/signkey type=ed25519 >/dev/null

vault policy write rewrap-only chapters/ch12/policies/rewrap-only.hcl
vault policy write encrypt-only chapters/ch12/policies/encrypt-only.hcl

echo
echo "Ready. Try:"
echo
echo '  CT=$(vault write -field=ciphertext transit/encrypt/orders \'
echo '        plaintext=$(base64 <<< "Hamburg"))'
echo '  vault write -field=plaintext transit/decrypt/orders \'
echo '        ciphertext="$CT" | base64 --decode'
