#!/usr/bin/env bash
# Chapter 18 - run material from Chapters 6, 9 and 12 against OpenBao.
#
# The only differences from the Vault versions are the binary name and
# the environment variables. That is the most useful fact about the fork.
set -euo pipefail

export BAO_ADDR="${BAO_ADDR:-http://127.0.0.1:8300}"
export BAO_TOKEN="${BAO_TOKEN:-root}"

echo "== Chapter 9: key/value v2 =="
bao secrets enable -path=meridian -version=2 kv 2>/dev/null || true
bao kv put meridian/tracking db_user=tracking_svc db_password=openbao-lab
bao kv patch meridian/tracking db_password=patched
bao kv get meridian/tracking

echo
echo "== Chapter 6: policies, including the data/ requirement =="
bao policy write tracking-read - <<'POL'
path "meridian/data/tracking" {
  capabilities = ["read"]
}
POL
T=$(bao token create -policy=tracking-read -format=json \
    | jq -r '.auth.client_token')
echo "-- permitted:"
BAO_TOKEN=$T bao kv get meridian/tracking >/dev/null && echo "   ok"
echo "-- denied:"
BAO_TOKEN=$T bao kv get meridian/billing 2>&1 | grep -q denied \
  && echo "   permission denied, as expected"

echo
echo "== Chapter 12: transit =="
bao secrets enable transit 2>/dev/null || true
bao write -f transit/keys/orders >/dev/null
CT=$(bao write -field=ciphertext transit/encrypt/orders \
     plaintext=$(base64 <<< "Hamburg"))
echo "   ciphertext prefix: $(echo "$CT" | cut -d: -f1-2):"
bao write -field=plaintext transit/decrypt/orders \
  ciphertext="$CT" | base64 --decode

echo
echo "The ciphertext prefix is still vault:v1: - changing it would have"
echo "broken every stored ciphertext at the fork."
