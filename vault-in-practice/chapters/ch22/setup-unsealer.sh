#!/usr/bin/env bash
# Chapter 22 - prepare OpenBao as the unsealer.
#
# The unsealer needs almost nothing: one transit key, one policy with two
# capabilities, one periodic token. It should be small, elsewhere, and
# operated by somebody other than the team running the main cluster.
set -euo pipefail
cd "$(dirname "$0")/../.."

docker compose up -d openbao
sleep 4

export BAO_ADDR="${BAO_ADDR:-http://127.0.0.1:8300}"
export BAO_TOKEN="${BAO_TOKEN:-root}"

bao secrets enable transit 2>/dev/null || true
bao write -f transit/keys/vault-unseal >/dev/null

# Two capabilities. Not read on the key, not sudo, nothing else.
bao policy write vault-unseal - <<'POL'
path "transit/encrypt/vault-unseal" {
  capabilities = ["update"]
}
path "transit/decrypt/vault-unseal" {
  capabilities = ["update"]
}
POL

# PERIODIC. A non-periodic token eventually reaches max_ttl, and the
# failure surfaces at the next restart - possibly months later, long
# after the change that caused it.
TOKEN=$(bao token create -policy=vault-unseal -period=24h \
  -format=json | jq -r '.auth.client_token')

echo "$TOKEN" > chapters/ch22/.unseal-token
chmod 600 chapters/ch22/.unseal-token

echo "seal token written to chapters/ch22/.unseal-token (git-ignored)"
echo "next: ./chapters/ch22/migrate-to-autounseal.sh"
