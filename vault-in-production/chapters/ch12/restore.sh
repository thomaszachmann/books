#!/usr/bin/env bash
# Chapter 12: restore a snapshot into a Vault installation that has
# never seen its seal, and time it.
#
#   ./chapters/ch12/restore.sh <snapshot> <init.json of its cluster>
#
# It uninstalls the release in namespace vault, deletes its volumes,
# installs it again with the same name, lets join.sh give it keys of
# its own, then restores with -force and unseals with the snapshot's
# keys. The Kubernetes cluster itself stays; the clock starts when
# three empty pods are running.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

SNAP=${1:?usage: restore.sh <snapshot> <old init.json>}
OLD=${2:?usage: restore.sh <snapshot> <old init.json>}
NS=${NS:-vault}
CTX=${CTX:-kind-vip}
K="kubectl --context $CTX -n $NS"
HERE=chapters/ch12

$K delete job,cronjob --all >/dev/null 2>&1 || true
helm --kube-context "$CTX" -n "$NS" uninstall vault --wait >/dev/null
$K delete pvc --all --wait >/dev/null
helm --kube-context "$CTX" -n "$NS" install vault hashicorp/vault \
  --version 0.29.1 -f "$HERE/values.yaml" >/dev/null
for p in vault-0 vault-1 vault-2; do
  until [ "$($K get pod "$p" -o jsonpath='{.status.phase}' \
        2>/dev/null)" = Running ]; do sleep 2; done
done

T0=$(date +%s)
stamp() { printf '[+%03ds]  %s\n' $(( $(date +%s) - T0 )) "$1"; }
stamp "three pods running"

# join.sh initialises vault-0, joins and unseals the other two and
# waits for failure tolerance 1. Its keys are this cluster's own.
OUT=/tmp/ch12-new-init.json CTX=$CTX NS=$NS \
  "$HERE/join.sh" >/dev/null
stamp "its own cluster initialised, joined, failure tolerance 1"

NEWROOT=$(jq -r .root_token /tmp/ch12-new-init.json)
$K exec -i vault-0 -- env VAULT_TOKEN="$NEWROOT" \
  vault operator raft snapshot restore -force /dev/stdin < "$SNAP"
stamp "snapshot restored with -force"

# From here the cluster belongs to the snapshot: its keys, its token.
mapfile -t KEYS < <(jq -r '.unseal_keys_b64[0:2][]' "$OLD")
for p in vault-0 vault-1 vault-2; do
  until $K exec "$p" -- vault status >/dev/null 2>&1 || \
        [ "$($K exec "$p" -- vault status -format=json 2>/dev/null \
             | jq -r .sealed)" = true ]; do sleep 1; done
  for k in "${KEYS[@]}"; do
    $K exec "$p" -- vault operator unseal "$k" >/dev/null 2>&1 || true
  done
done
stamp "all three unsealed with the snapshot's keys"

ROOT=$(jq -r .root_token "$OLD")
until v=$($K exec vault-0 -- env VAULT_TOKEN="$ROOT" \
      vault kv get -field=pass prod/payments/db 2>/dev/null); do
  sleep 2
done
stamp "first secret read: $v"
echo
$K exec vault-0 -- env VAULT_TOKEN="$ROOT" \
  vault operator raft list-peers
