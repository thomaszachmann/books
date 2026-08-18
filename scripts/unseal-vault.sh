#!/usr/bin/env bash
# Unseal using the first `threshold` keys from init.json.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$ROOT/lab/tls/vault-cert.pem}"

[ -f "$ROOT/init.json" ] || { echo "No init.json. Run: make init" >&2; exit 1; }

THRESHOLD=$(jq -r '.unseal_threshold // 3' "$ROOT/init.json")

for i in $(seq 0 $((THRESHOLD-1))); do
  KEY=$(jq -r ".unseal_keys_b64[$i]" "$ROOT/init.json")
  vault operator unseal "$KEY" >/dev/null
  echo "  unseal key $((i+1))/$THRESHOLD accepted"
done

vault status | grep -E "Sealed|HA Mode" || true
echo
echo "Export your token:  export VAULT_TOKEN=\$(jq -r .root_token init.json)"
