#!/usr/bin/env bash
# Destroy all Vault data and start again from an uninitialised server.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "This deletes:"
echo "  - all Vault data in data/"
echo "  - all audit logs in logs/"
echo "  - init.json, including the unseal keys"
echo
read -r -p "Type RESET to continue: " confirm
[ "$confirm" = "RESET" ] || { echo "Aborted."; exit 1; }

docker compose -f docker-compose.yml down
rm -rf data/* logs/* init.json
docker compose -f docker-compose.yml up -d vault
"$ROOT/scripts/wait-for-vault.sh"

echo
echo "Reset complete. Vault is uninitialised and sealed."
echo "Next: make init && make unseal"
