#!/usr/bin/env bash
# Initialise vault-0, join the other pods, unseal all three.
# The chart does none of this for you.
set -euo pipefail

NS=${NS:-vault}
CTX=${CTX:-kind-vip}
K="kubectl --context $CTX -n $NS"
OUT=${OUT:-./init.json}

wait_running() {
  until $K get pod "$1" -o jsonpath='{.status.phase}' 2>/dev/null \
        | grep -q Running; do sleep 2; done
}

for p in vault-0 vault-1 vault-2; do wait_running "$p"; done

$K exec vault-0 -- vault operator init \
    -key-shares=3 -key-threshold=2 -format=json > "$OUT"
mapfile -t KEYS < <(jq -r '.unseal_keys_b64[0:2][]' "$OUT")

unseal() { for k in "${KEYS[@]}"; do
             $K exec "$1" -- vault operator unseal "$k" >/dev/null
           done; }

unseal vault-0
for p in vault-1 vault-2; do
  # Join BEFORE unsealing. Before the join the pod is an
  # uninitialised Vault of its own, and unsealing it fails with
  #   Code: 400. Errors: * Vault is not initialized
  $K exec "$p" -- vault operator raft join \
      http://vault-0.vault-internal:8200
  unseal "$p"
done

ROOT=$(jq -r .root_token "$OUT")
until [ "$($K exec vault-0 -- sh -c \
      "VAULT_TOKEN=$ROOT vault operator raft autopilot state \
       -format=json" 2>/dev/null | jq -r .FailureTolerance)" = "1" ]
  do sleep 2
done
echo "failure tolerance 1; keys and root token are in $OUT"
