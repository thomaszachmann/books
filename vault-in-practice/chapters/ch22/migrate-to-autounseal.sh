#!/usr/bin/env bash
# Chapter 22 - migrate the seal from Shamir to transit.
#
# This is the ONLY moment in an auto-unseal deployment when human key
# holders are required. Schedule it deliberately, with them present.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"

TOKEN=$(cat chapters/ch22/.unseal-token)

cp config/vault.hcl config/vault-shamir.hcl.bak

grep -q 'seal "transit"' config/vault.hcl || cat >> config/vault.hcl <<CFG

# In production this token belongs in a systemd drop-in with mode 0600,
# or in VAULT_SEAL_TRANSIT_TOKEN from the platform - not in a file you
# keep in Git.
seal "transit" {
  address         = "http://host.docker.internal:8300"
  token           = "$TOKEN"
  key_name        = "vault-unseal"
  mount_path      = "transit/"
  disable_renewal = "false"
}
CFG

docker compose restart vault
sleep 5
vault status || true

echo
echo "Supplying the existing Shamir keys with -migrate:"
for i in 0 1 2; do
  KEY=$(jq -r ".unseal_keys_b64[$i]" init.json)
  vault operator unseal -migrate "$KEY" >/dev/null 2>&1 || true
done
sleep 2
vault status | grep -E "Seal Type|Recovery Seal|Sealed" || true

echo
echo "Now restart and watch nobody do anything:"
echo "  docker compose restart vault && sleep 6 && vault status"
