#!/usr/bin/env bash
# Initialise once, against node 1. The other two join by retry_join and
# are unsealed with the same keys - one Raft cluster shares one root key.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
export VAULT_ADDR=https://127.0.0.1:8210 VAULT_CACERT="$PWD/cluster/tls/cert.pem"

if [ -f cluster/init.json ]; then
  echo "cluster/init.json exists - already initialised. Refusing to overwrite."
  exit 1
fi
vault operator init -format=json -key-shares=5 -key-threshold=3 > cluster/init.json
chmod 600 cluster/init.json
echo "Initialised. Keys and root token are in cluster/init.json."
echo "In production that file would not exist; see Chapter 7."
