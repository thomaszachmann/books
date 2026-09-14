#!/usr/bin/env bash
# Chapter 22 - point Vault's transit seal at the HSM-sealed unsealer.
#
# The result is a chain with no Shamir key anywhere in daily operation:
#   Vault  <- transit <-  OpenBao  <- pkcs11 <-  HSM
#
# This is a migration between two seals of the SAME type. Vault allows
# it: the disabled block is the old seal, the enabled one the new, and
# because both are auto-seals the keys you supply with -migrate are the
# RECOVERY keys - which, since the first migration, are the Shamir keys
# from init.json under a new name.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Three compose files share one project; without this, each one calls
# the others' containers orphans.
export COMPOSE_IGNORE_ORPHANS=1

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"

seal_type=$(vault status -format=json 2>/dev/null | jq -r '.type // "shamir"')
if [ "$seal_type" != "transit" ]; then
  echo "Vault is on '$seal_type', not transit. Run the chapter's"
  echo "migrate-to-autounseal.sh first; this script replaces one transit"
  echo "unsealer with another."
  exit 1
fi

TOKEN=$(cat chapters/ch22/.unseal-token-hsm)
cp config/vault.hcl config/vault-transit-dev.hcl.bak

# Old seal: keep the block, mark it disabled. Vault needs it to decrypt
# the root key DURING the migration. New seal: a second transit block.
python3 - <<'PY'
import pathlib
p = pathlib.Path("config/vault.hcl"); s = p.read_text()
if 'openbao-hsm' not in s and 'disabled = "true"' not in s:
    s = s.replace('seal "transit" {', 'seal "transit" {\n  disabled = "true"', 1)
    p.write_text(s)
PY
grep -q 'openbao-hsm:8200' config/vault.hcl || cat >> config/vault.hcl <<CFG

# The unsealer is itself auto-unsealed by an HSM. No human key holder is
# needed for any restart in this chain - only for generate-root and rekey.
seal "transit" {
  address         = "http://openbao-hsm:8200"
  token           = "$TOKEN"
  key_name        = "vault-unseal"
  mount_path      = "transit/"
  disable_renewal = "false"
}
CFG

docker compose restart vault
sleep 5
docker logs --since 10s vault 2>&1 | grep -i "seal migration mode" | sed 's/.*\[WARN\] */  /' || true

echo
echo "Supplying the RECOVERY keys with -migrate:"
for i in 0 1 2; do
  vault operator unseal -migrate \
    "$(jq -r ".unseal_keys_b64[$i]" init.json)" >/dev/null 2>&1 || true
done
sleep 2
vault status | grep -E "Seal Type|Recovery Seal|Sealed"
docker logs --since 10s vault 2>&1 | grep -i "seal migration complete" | sed 's/.*\[INFO\] */  /' || true

# The old block has done its job. Remove it so the next migration has a
# clean pair to work with.
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("config/vault.hcl"); s = p.read_text()
s = re.sub(r'\n(# In production[^\n]*\n(#[^\n]*\n)*)?seal "transit" \{\n  disabled = "true"[\s\S]*?\n\}\n', '\n', s, count=1)
p.write_text(s)
PY

echo
echo "Now restart BOTH, unsealer first, and watch nobody do anything:"
echo "  docker compose -f docker-compose.yml -f docker-compose.hsm.yml restart openbao-hsm"
echo "  sleep 6 && docker compose restart vault && sleep 8 && vault status"
