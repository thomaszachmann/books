#!/usr/bin/env bash
# Chapter 22 - build the circular dependency on purpose.
#
# Vault asks itself to decrypt the key it needs in order to start
# answering. It retries forever. Seeing it once is worth more than
# reading the paragraph.
set -uo pipefail
cd "$(dirname "$0")/../.."

cp config/vault.hcl config/vault-transit.hcl.bak
python3 - <<'PY'
import pathlib
p = pathlib.Path("config/vault.hcl"); s = p.read_text()
p.write_text(s.replace("http://host.docker.internal:8300",
                       "https://127.0.0.1:8200"))
PY

docker compose restart vault
sleep 8
echo "== the log =="
docker compose logs vault --tail 8 | grep -i -E "unseal|transit" || true

echo
echo "== restoring =="
cp config/vault-transit.hcl.bak config/vault.hcl
docker compose restart vault
sleep 6
VAULT_ADDR=https://127.0.0.1:8200 \
VAULT_CACERT="$PWD/tls/vault-cert.pem" vault status | grep Sealed

echo
echo "The same loop hides better with a cloud KMS: the KMS credential"
echo "kept in Vault, or a KMS behind a network policy managed by a system"
echo "that authenticates against Vault. Look for the loop, not for this"
echo "literal misconfiguration."
