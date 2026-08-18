#!/usr/bin/env bash
# Chapter 20 - record enough state to prove a migration lost nothing.
#
# A migration you cannot verify is a migration you cannot defend.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

echo "== secrets engines =="
vault secrets list -format=json | jq -r 'keys[]' | sort
echo "== auth methods =="
vault auth list -format=json | jq -r 'keys[]' | sort
echo "== policies =="
vault policy list | sort
echo "== kv canary =="
vault kv get -format=json meridian/tracking 2>/dev/null \
  | jq -r '.data.data' || echo "(absent)"
