#!/usr/bin/env bash
# Chapter 10, Steps 2 to 4. Restore carry/ onto a host that has never
# seen this cluster, and time every phase.
#
#   ./chapters/ch10/rehearse.sh       # on the recovery host
#
# On a single machine this deletes the lab first ('make reset'), which
# is the same thing as a host that has never been part of the cluster.
# The keys for the snapshot come from carry/keys.json, not from the
# new cluster's own init.json.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
IN=chapters/ch10/carry
[ -f "$IN/prod.snap" ] && [ -f "$IN/keys.json" ] \
  || { echo "no $IN/prod.snap or keys.json - run carry.sh first" >&2; exit 1; }
( cd "$IN" && sha256sum -c --quiet prod.snap.sha256 ) \
  || { echo "snapshot hash does not match - do not restore it" >&2; exit 1; }

make -s reset >/dev/null
T0=$(date +%s)
stamp() { printf '[+%03ds]  %s\n' $(( $(date +%s) - T0 )) "$1"; }
stamp "start: empty host, this seal has never been here"
make -s up >/dev/null
stamp "three nodes running"
make -s init >/dev/null
stamp "its own cluster initialised"
make -s unseal >/dev/null
stamp "unsealed"

. ./scripts/vault-env.sh
until [ "$(vault operator raft autopilot state -format=json 2>/dev/null \
      | jq -r .FailureTolerance)" = "1" ]; do sleep 2; done
stamp "failure tolerance 1 reached"

vault operator raft snapshot restore -force "$IN/prod.snap"
stamp "snapshot restored with -force"

# From here on the cluster belongs to the snapshot: its keys, its
# root token. The new cluster's init.json is now worthless.
cp "$IN/keys.json" cluster/init.json
make -s unseal >/dev/null
stamp "unsealed with the foreign keys"

. ./scripts/vault-env.sh
# The first error while waiting is the one to recognise in a real
# recovery. It is printed once, not once per attempt.
first="" seen=""
until first=$(vault kv get -field=pass prod/payments/db 2>/tmp/ch10.err); do
  err=$(grep -m1 '^\*' /tmp/ch10.err || true)
  [ -n "$err" ] && [ "$err" != "$seen" ] && { stamp "a read fails: $err"; seen=$err; }
  sleep 2
done
stamp "first secret read: $first"

echo
echo "  prod/app holds $(vault kv list -format=json prod/app | jq length) secrets"
vault token lookup -format=json | jq -r '"  token in use: \(.data.policies|join(",")), ttl \(.data.ttl)"'
