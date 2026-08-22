#!/usr/bin/env bash
# Unseal all three nodes with the same three shares.
#
# Two traps live in this script, both worth knowing.
#
# 1. Nodes 2 and 3 cannot be unsealed until they have joined. retry_join
#    fetches the seal configuration from the leader; before it arrives a
#    node logs "security barrier not initialized" and ignores the keys.
#
# 2. 'vault status' exits 2 when Vault is sealed - that is its way of
#    reporting the seal state, not an error. Under 'set -o pipefail' the
#    exit code poisons the whole pipeline even when jq succeeded, so the
#    output is captured first and parsed afterwards.
set -euo pipefail
. "$(dirname "$0")/engine.sh"
cd "$(dirname "$0")/.." || exit 1
export VAULT_CACERT="$PWD/cluster/tls/cert.pem"
command -v jq >/dev/null || { echo "jq required"; exit 1; }
[ -f cluster/init.json ] || { echo "run 'make init' first"; exit 1; }

status_json() {
  VAULT_ADDR="https://127.0.0.1:$1" vault status -format=json 2>/dev/null || true
}

field() {  # field <port> <jq-filter>
  local out; out=$(status_json "$1")
  [ -n "$out" ] || return 1
  printf '%s' "$out" | jq -e "$2" >/dev/null 2>&1
}

node=0
for port in 8210 8220 8230; do
  node=$((node + 1))
  for _ in $(seq 60); do
    field "$port" '.initialized' && break
    sleep 1
  done
  if ! field "$port" '.initialized'; then
    echo "  $port  vault-$node has not joined - try: $ENGINE logs vip-vault-$node"
    continue
  fi

  export VAULT_ADDR="https://127.0.0.1:$port"
  for i in 0 1 2; do
    field "$port" '.sealed == false' && break
    vault operator unseal "$(jq -r ".unseal_keys_b64[$i]" cluster/init.json)" >/dev/null
  done
  # A node that has just unsealed spends a moment electing or joining,
  # and 'vault status' can return nothing at all in that window. One
  # reading is not evidence.
  state="STILL SEALED"
  for _ in $(seq 10); do
    if field "$port" '.sealed == false'; then state="unsealed"; break; fi
    sleep 1
  done
  printf "  %s  vault-%s  %s\n" "$port" "$node" "$state"
done
