#!/usr/bin/env bash
# Chapter 22 - migrate back. Know both directions before you need either.
#
# disabled = "true" rather than deleting the block: Vault needs the seal
# configuration to decrypt the existing root key DURING the migration
# away from it.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"

python3 - <<'PY'
import pathlib
p = pathlib.Path("config/vault.hcl"); s = p.read_text()
if 'disabled = "true"' not in s:
    s = s.replace('seal "transit" {',
                  'seal "transit" {\n  disabled = "true"')
    p.write_text(s)
PY

docker compose restart vault
sleep 5
for i in 0 1 2; do
  vault operator unseal -migrate \
    "$(jq -r ".unseal_keys_b64[$i]" init.json)" >/dev/null 2>&1 || true
done
sleep 2
vault status | grep -E "Seal Type|Sealed"

echo
echo "If the KMS ever becomes permanently unavailable, this is your"
echo "recovery path - and it requires a RUNNING Vault. A Vault that"
echo "cannot start cannot be migrated."
