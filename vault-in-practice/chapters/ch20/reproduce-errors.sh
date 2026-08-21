#!/usr/bin/env bash
# Chapter 20 - the migration errors, on purpose.
#
# Works on a throwaway copy under /tmp, not on your lab: a migration that
# goes wrong is exactly what this produces, and it should not go wrong on
# data you want.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/config" "$W/data" "$W/raft"
chmod 777 "$W/data" "$W/raft"
IMG="hashicorp/vault:1.18"
PORT=18690

cat > "$W/config/file.hcl" <<CFG
disable_mlock = true
storage "file" { path = "/vault/data" }
listener "tcp" { address = "0.0.0.0:8200"  tls_disable = true }
api_addr = "http://127.0.0.1:8200"
CFG
cat > "$W/config/migrate-no-cluster.hcl" <<CFG
storage_source "file"  { path = "/vault/data" }
storage_destination "raft" { path = "/vault/raft"  node_id = "n1" }
CFG
cat > "$W/config/migrate.hcl" <<CFG
cluster_addr = "http://127.0.0.1:8201"
storage_source "file"  { path = "/vault/data" }
storage_destination "raft" { path = "/vault/raft"  node_id = "n1" }
CFG
cat > "$W/config/raft.hcl" <<CFG
disable_mlock = true
storage "raft" { path = "/vault/data"  node_id = "n1" }
listener "tcp" { address = "0.0.0.0:8200"  tls_disable = true }
api_addr = "http://127.0.0.1:8200"
CFG
cat > "$W/config/raft-ha.hcl" <<CFG
disable_mlock = true
storage "raft" { path = "/vault/data"  node_id = "n1" }
listener "tcp" { address = "0.0.0.0:8200"  tls_disable = true }
api_addr     = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
CFG

mig() { docker run --rm -v "$W/config:/vault/config:ro" \
          -v "$W/data:/vault/data" -v "$W/raft:/vault/raft" "$IMG" \
          vault operator migrate -config="/vault/config/$1" 2>&1 \
          | grep -v "chown\|appropriate permissions"; }

docker rm -f wwr20 >/dev/null 2>&1 || true
docker run -d --rm --name wwr20 -p "$PORT:8200" \
  -v "$W/config:/vault/config:ro" -v "$W/data:/vault/data" "$IMG" \
  vault server -config=/vault/config/file.hcl >/dev/null
export VAULT_ADDR="http://127.0.0.1:$PORT"
unset VAULT_CACERT
for _ in $(seq 30); do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$VAULT_ADDR/v1/sys/health" 2>/dev/null || echo 000)
  [ "$c" = "501" ] && break; sleep 1
done
vault operator init -format=json -key-shares=1 -key-threshold=1 > "$W/init.json"
vault operator unseal "$(jq -r '.unseal_keys_b64[0]' "$W/init.json")" >/dev/null
VAULT_TOKEN=$(jq -r .root_token "$W/init.json"); export VAULT_TOKEN
vault secrets enable -path=demo -version=2 kv >/dev/null 2>&1
vault kv put demo/x a=b >/dev/null
echo "A file-backed Vault with something in it. storage_type: $(vault status -format=json | jq -r .storage_type)"

wwr_case "cluster_addr config not set"
echo "The first migration attempt usually fails before it starts:"
mig migrate-no-cluster.hcl | tail -2 | sed 's/^/  /'
echo "Raft needs cluster_addr, and 'operator migrate' needs it in the"
echo "MIGRATION file, not only in the server configuration. This is the"
echo "same missing setting that later reports HA Enabled false."

wwr_case "raft locks its storage, file does not"
echo "A second process against the same RAFT directory is refused:"
mkdir -p "$W/raftdir"; chmod 777 "$W/raftdir"
cat > "$W/config/raft-lock.hcl" <<CFG
disable_mlock = true
storage "raft" { path = "/vault/data"  node_id = "n1" }
listener "tcp" { address = "0.0.0.0:8200"  tls_disable = true }
api_addr     = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
CFG
docker rm -f wwr20r >/dev/null 2>&1 || true
docker run -d --rm --name wwr20r -v "$W/config:/vault/config:ro" \
  -v "$W/raftdir:/vault/data" "$IMG" \
  vault server -config=/vault/config/raft-lock.hcl >/dev/null 2>&1
sleep 5
docker run --rm -v "$W/config:/vault/config:ro" -v "$W/raftdir:/vault/data" "$IMG" \
  vault server -config=/vault/config/raft-lock.hcl 2>&1 \
  | grep -viE "chown|appropriate" | grep -iE "bolt file|error initializing storage" \
  | head -1 | sed 's/^/  /'
docker rm -f wwr20r >/dev/null 2>&1
echo
echo "The file backend does not. This is measured on a native Linux host,"
echo "not inferred from a laptop:"
docker run --rm -v "$W/config:/vault/config:ro" -v "$W/data:/vault/data" "$IMG" \
  sh -c 'timeout 8 vault server -config=/vault/config/vault.hcl 2>&1 | grep -c "Vault server started"' \
  2>/dev/null | sed 's/^/  second process started (1 = yes): /'

wwr_case "migrating while Vault is still running"
echo "The chapter says to stop the container first. On this platform the"
echo "migration is not refused - it copies happily from underneath a"
echo "running Vault, which is worse than an error:"
mig migrate.hcl | tail -1 | sed 's/^/  /'
echo "Stop the container before migrating. Nothing will tell you to."
docker stop wwr20 >/dev/null 2>&1

wwr_case "the destination is not empty"
echo "Run the same migration a second time:"
mig migrate.hcl | tail -1 | sed 's/^/  /'
echo "Clear the destination, or pick a fresh directory."

wwr_case "HA Enabled false after migrating to Raft"
rm -rf "$W/data"; mkdir -p "$W/data"; chmod 777 "$W/data"
cp -R "$W/raft/." "$W/data/" 2>/dev/null || true
start() { docker rm -f wwr20 >/dev/null 2>&1
  docker run -d --rm --name wwr20 -p "$PORT:8200" \
    -v "$W/config:/vault/config:ro" -v "$W/data:/vault/data" "$IMG" \
    vault server -config="/vault/config/$1" >/dev/null
  for _ in $(seq 30); do
    c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$VAULT_ADDR/v1/sys/health" 2>/dev/null || echo 000)
    case "$c" in 501|503|200|429) return 0;; esac; sleep 1
  done; }
start raft.hcl
vault operator unseal "$(jq -r '.unseal_keys_b64[0]' "$W/init.json")" >/dev/null 2>&1 || true
printf '  without cluster_addr: HA Enabled %s\n' \
  "$(vault status -format=json 2>/dev/null | jq -r '.ha_enabled')"
start raft-ha.hcl
vault operator unseal "$(jq -r '.unseal_keys_b64[0]' "$W/init.json")" >/dev/null 2>&1 || true
printf '  with cluster_addr   : HA Enabled %s\n' \
  "$(vault status -format=json 2>/dev/null | jq -r '.ha_enabled')"
echo "Silent on a single node, which is how it survives to production."
docker rm -f wwr20 >/dev/null 2>&1

echo
echo "Not reproduced here, and each for a reason:"
echo "  - 'resource temporarily unavailable' needs the file backend to"
echo "    refuse a second process. On this platform it does not; a second"
echo "    server started against the same directory without complaint."
echo "    The message is real, the condition is not one a laptop makes."
echo "  - node_id conflicts on replacement, and a snapshot restored into"
echo "    a different seal, both need a second installation. Chapter 21"
echo "    and Chapter 22 build those."
wwr_done
