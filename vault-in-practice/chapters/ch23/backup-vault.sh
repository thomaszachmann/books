#!/usr/bin/env bash
# Chapter 23 - a snapshot plus the one thing that makes it restorable.
#
# A usable backup is three things: the snapshot, the means to unseal it,
# and knowledge of WHICH SEAL it belongs to. The manifest records the
# third, which is what stops somebody restoring a transit-sealed snapshot
# into a Shamir cluster and concluding the backup is corrupt.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first}"

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p backups
OUT="backups/vault-$STAMP.snap"

vault operator raft snapshot save "$OUT"

SIZE=$(wc -c < "$OUT" | tr -d ' ')
[ "$SIZE" -gt 1000 ] || {
  echo "snapshot suspiciously small - refusing to record it" >&2
  exit 1; }

SEAL=$(vault status -format=json | jq -r '.type')
echo "$STAMP  ${SIZE}B  seal=$SEAL" >> backups/manifest.txt

echo "saved $OUT (${SIZE} bytes, seal=$SEAL)"
echo "This snapshot is useless without $SEAL access. Record that"
echo "somewhere the snapshot is not."
