#!/usr/bin/env bash
# Chapter 22 - move Vault from the transit seal to AWS KMS.
#
# Same shape as every migration in this chapter: the old seal stays in
# the file, disabled, so Vault can still decrypt the root key while it
# re-wraps it under the new one. Because both are auto-seals, the keys
# you supply with -migrate are the RECOVERY keys.
#
# The credentials sit in the seal stanza here because moto ignores them.
# On AWS they would not be here at all: an instance profile, an IRSA
# role, or the VAULT_AWSKMS_SEAL_KEY_ID / AWS_* environment. A seal
# stanza with a real secret_key in it is a finding, not a configuration.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Three compose files share one project; without this, each one calls
# the others' containers orphans.
export COMPOSE_IGNORE_ORPHANS=1

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"

seal_type=$(vault status -format=json 2>/dev/null | jq -r '.type // "shamir"')
case "$seal_type" in
  transit) ;;
  awskms) echo "Already on awskms."; exit 0 ;;
  *) echo "Vault is on '$seal_type'. This script migrates FROM transit;"
     echo "run migrate-to-autounseal.sh first."; exit 1 ;;
esac

cp config/vault.hcl config/vault-transit.hcl.bak

python3 - <<'PY'
import pathlib
p = pathlib.Path("config/vault.hcl"); s = p.read_text()
if 'seal "awskms"' not in s:
    s = s.replace('seal "transit" {', 'seal "transit" {\n  disabled = "true"', 1)
    s += '''
seal "awskms" {
  region     = "eu-central-1"
  kms_key_id = "alias/vault-unseal"
  endpoint   = "http://moto:5000"
  access_key = "test"
  secret_key = "test"
}
'''
    p.write_text(s)
PY

docker compose restart vault
sleep 5
docker logs --since 10s vault 2>&1 | grep -i "seal migration mode" | sed 's/.*\[WARN\] */  /' || true

echo
echo "Supplying the RECOVERY keys with -migrate:"
for i in 0 1 2; do
  vault operator unseal -migrate \
    "$(jq -r ".unseal_keys_b64[$i]" init.json)" >/dev/null 2>&1 || true
done
sleep 3
vault status | grep -E "Seal Type|Recovery Seal|Sealed"
docker logs --since 12s vault 2>&1 | grep -i "migrating from\|migration complete" \
  | sed 's/.*core: */  /' || true

# Drop the disabled transit block; the migration is done.
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("config/vault.hcl"); s = p.read_text()
s = re.sub(r'\n(#[^\n]*\n)*seal "transit" \{\n  disabled = "true"[\s\S]*?\n\}\n', '\n', s, count=1)
p.write_text(s)
PY

echo
echo "Restart and watch nobody do anything:"
echo "  docker compose restart vault && sleep 6 && vault status"
