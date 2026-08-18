#!/usr/bin/env bash
# Chapter 20 - migrate a live installation from file to Raft.
#
# Three things to know before running this:
#   1. Vault must be STOPPED, not sealed. The migration touches storage.
#   2. It COPIES. The source is left intact, so the rollback is to start
#      the old configuration again.
#   3. The unseal keys do NOT change. The encryption key travels with the
#      data, still encrypted by the same root key.
set -euo pipefail
cd "$(dirname "$0")/../.."

VER="hashicorp/vault:1.18"

echo "== 1. canary =="
export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
if [ -n "${VAULT_TOKEN:-}" ]; then
  vault kv put meridian/migration-canary \
    written_before=file-storage >/dev/null 2>&1 || true
fi

echo "== 2. stopping Vault =="
docker compose stop vault

echo "== 3. migration config =="
mkdir -p raft
cat > config/migrate.hcl <<'CFG'
storage_source "file" {
  path = "/vault/data"
}

storage_destination "raft" {
  path    = "/vault/raft"
  node_id = "vault-1"
}

cluster_addr = "https://127.0.0.1:8201"
CFG

echo "== 4. migrating =="
docker run --rm \
  -v "$PWD/config:/vault/config:ro" \
  -v "$PWD/data:/vault/data" \
  -v "$PWD/raft:/vault/raft" \
  "$VER" \
  vault operator migrate -config=/vault/config/migrate.hcl

echo "== 5. switching the server configuration =="
cp config/vault.hcl config/vault-file.hcl.bak
cp chapters/ch20/config/vault-raft.hcl config/vault.hcl

# The raft directory has to be mounted.
python3 - <<'PY'
import pathlib
p = pathlib.Path("docker-compose.yml"); s = p.read_text()
if "./raft:/vault/raft" not in s:
    s = s.replace("      - ./data:/vault/data",
                  "      - ./data:/vault/data\n      - ./raft:/vault/raft", 1)
    p.write_text(s)
    print("   raft volume added to docker-compose.yml")
PY

echo "== 6. starting =="
docker compose up -d vault
sleep 4
vault status || true

echo
echo "Unseal with THE SAME keys - nothing was re-initialised:"
echo "  make unseal"
echo
echo "Rollback, if needed: cp config/vault-file.hcl.bak config/vault.hcl"
echo "The file data in data/ is untouched."
