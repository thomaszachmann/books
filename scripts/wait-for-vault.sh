#!/usr/bin/env bash
# Block until Vault answers its seal-status endpoint.
set -euo pipefail

ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
CACERT="${VAULT_CACERT:-$(cd "$(dirname "$0")/.." && pwd)/lab/tls/vault-cert.pem}"

for i in $(seq 1 30); do
  if curl -sf --cacert "$CACERT" "$ADDR/v1/sys/seal-status" >/dev/null 2>&1; then
    echo "Vault is answering on $ADDR"
    exit 0
  fi
  sleep 1
done

echo "Vault did not answer within 30 seconds." >&2
echo "Check: docker compose -f lab/docker-compose.yml logs vault" >&2
exit 1
