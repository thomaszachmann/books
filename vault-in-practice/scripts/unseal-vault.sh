#!/usr/bin/env bash
# Unseal using the first three keys from .env.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$ROOT/tls/vault-cert.pem}"

[ -f "$ROOT/.env" ] || { echo "No .env. Run: make init" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ROOT/.env"

for n in 1 2 3; do
  eval "KEY=\${KEY$n:-}"
  [ -n "$KEY" ] || { echo "KEY$n missing from .env" >&2; exit 1; }
  vault operator unseal "$KEY" >/dev/null
  echo "  unseal key $n/3 accepted"
done

vault status | grep -E "Sealed|HA Mode" || true
echo
echo "Export your token:  source .env"
