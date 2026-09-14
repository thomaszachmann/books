#!/usr/bin/env bash
# Chapter 22 - leave AWS KMS again, back to the transit unsealer.
#
# This is the exit you plan BEFORE you need it. It requires the KMS key to
# still work: a Vault whose key is gone cannot be migrated, because it
# cannot start. Do this while the key exists, or never.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Three compose files share one project; without this, each one calls
# the others' containers orphans.
export COMPOSE_IGNORE_ORPHANS=1

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"

seal_type=$(vault status -format=json 2>/dev/null | jq -r '.type // "shamir"')
[ "$seal_type" = "awskms" ] || { echo "Vault is on '$seal_type', not awskms."; exit 1; }

UNSEALER_TOKEN_FILE=chapters/ch22/.unseal-token
UNSEALER_ADDR="http://openbao:8200"
if [ -f chapters/ch22/.unseal-token-hsm ] && docker ps --format '{{.Names}}' | grep -qx openbao-hsm; then
  UNSEALER_TOKEN_FILE=chapters/ch22/.unseal-token-hsm
  UNSEALER_ADDR="http://openbao-hsm:8200"
fi
TOKEN=$(cat "$UNSEALER_TOKEN_FILE")

python3 - <<PY
import pathlib
p = pathlib.Path("config/vault.hcl"); s = p.read_text()
if 'seal "transit"' not in s:
    s = s.replace('seal "awskms" {', 'seal "awskms" {\n  disabled = "true"', 1)
    s += '''
seal "transit" {
  address         = "$UNSEALER_ADDR"
  token           = "$TOKEN"
  key_name        = "vault-unseal"
  mount_path      = "transit/"
  disable_renewal = "false"
}
'''
    p.write_text(s)
PY

docker compose restart vault
sleep 5
for i in 0 1 2; do
  vault operator unseal -migrate \
    "$(jq -r ".unseal_keys_b64[$i]" init.json)" >/dev/null 2>&1 || true
done
sleep 3
vault status | grep -E "Seal Type|Sealed"

python3 - <<'PY'
import pathlib, re
p = pathlib.Path("config/vault.hcl"); s = p.read_text()
s = re.sub(r'\nseal "awskms" \{\n  disabled = "true"[\s\S]*?\n\}\n', '\n', s, count=1)
p.write_text(s)
PY
echo "Back on transit. The KMS key is no longer needed by this Vault."
