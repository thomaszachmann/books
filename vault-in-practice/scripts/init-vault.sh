#!/usr/bin/env bash
# Initialise Vault with the book's defaults: 5 shares, threshold 3.
#
# Schreibt die Schluessel in .env, nicht in init.json. Grund steht in
# Kapitel 3: der Leser soll die Werte sehen und tippen, und .env laesst
# sich mit "source" laden, ohne dass jq im Spiel ist.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$ROOT/tls/vault-cert.pem}"

if [ -f "$ROOT/.env" ] && grep -q '^KEY1=' "$ROOT/.env"; then
  echo ".env already holds unseal keys. Refusing to overwrite it." >&2
  echo "If this Vault really is uninitialised, move the file aside." >&2
  exit 1
fi

OUT=$(vault operator init -key-shares=5 -key-threshold=3)
printf '%s\n' "$OUT"

{
  echo "VAULT_ADDR=$VAULT_ADDR"
  echo "VAULT_CACERT=$VAULT_CACERT"
  printf '%s\n' "$OUT" | awk '/^Unseal Key [0-9]+:/{print "KEY" $3+0 "=" $NF}'
  printf '%s\n' "$OUT" | awk '/^Initial Root Token:/{print "VAULT_TOKEN=" $NF}'
} > "$ROOT/.env"
chmod 600 "$ROOT/.env"

echo
echo "Keys and root token are in .env (chmod 600)."
echo "In production this file would not exist. See Chapter 3."
echo "Next: make unseal"
