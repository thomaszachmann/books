#!/usr/bin/env bash
# Chapter 10, Step 1. Give the running cluster production-shaped data,
# take a snapshot, and put the two things a recovery host needs into
# carry/: the snapshot and the unseal keys that are valid for it.
#
#   ./chapters/ch10/carry.sh          # against the lab from 'make up'
#
# carry/ lives outside cluster/ on purpose: 'make reset' deletes
# cluster/, and with it the only copy of the keys this snapshot opens
# with.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/vault-env.sh
OUT=chapters/ch10/carry
mkdir -p "$OUT"

vault secrets enable -path=prod -version=2 kv >/dev/null 2>&1 || true
vault kv put prod/payments/db user=svc-pay pass=Ahz7-Kq2 >/dev/null
vault kv put prod/tls/wildcard cn='*.meridian.test' >/dev/null
for i in $(seq 1 50); do vault kv put "prod/app/s$i" v="$i" >/dev/null; done

vault operator raft snapshot save "$OUT/prod.snap"
cp cluster/init.json "$OUT/keys.json"
chmod 600 "$OUT/keys.json"
( cd "$OUT" && sha256sum prod.snap > prod.snap.sha256 )

n=$(( $(vault kv list -format=json prod/app | jq length) + 2 ))
printf '  %s secrets\n  snapshot %s\n  sha256 %s\n' "$n" \
  "$(du -h "$OUT/prod.snap" | cut -f1)" \
  "$(cut -c1-24 "$OUT/prod.snap.sha256")..."
echo "Carry $OUT/ to the recovery host. Nothing else."
