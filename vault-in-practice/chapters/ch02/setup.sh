#!/usr/bin/env bash
# Chapter 2 - build the lab from nothing.
set -euo pipefail
cd "$(dirname "$0")/../.."

./scripts/check-prereqs.sh
./tls/generate-certs.sh
docker compose -f lab/docker-compose.yml up -d vault
./scripts/wait-for-vault.sh

echo
echo "Expected state: Initialized false, Sealed true"
VAULT_ADDR=https://127.0.0.1:8200 \
VAULT_CACERT="$PWD/tls/vault-cert.pem" \
  vault status || true
