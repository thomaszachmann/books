#!/usr/bin/env bash
# Initialise Vault with the book's defaults: 5 shares, threshold 3.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$ROOT/lab/tls/vault-cert.pem}"

if [ -f "$ROOT/init.json" ]; then
  echo "init.json already exists. Refusing to overwrite it." >&2
  echo "If this Vault really is uninitialised, move the file aside." >&2
  exit 1
fi

vault operator init -key-shares=5 -key-threshold=3 -format=json \
  > "$ROOT/init.json"
chmod 600 "$ROOT/init.json"

echo "Initialised. Keys and root token are in init.json (chmod 600)."
echo
echo "In production this file would not exist. See Chapter 3."
echo "Next: make unseal"
