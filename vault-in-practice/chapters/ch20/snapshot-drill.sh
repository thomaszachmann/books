#!/usr/bin/env bash
# Chapter 20 - prove the snapshot restores before you rely on it.
#
# Note what this demonstrates: a snapshot undoes a kv destroy. "Permanently
# destroyed" is true of the live system and not of your backups.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first}"

vault kv put meridian/restore-test v=before-snapshot >/dev/null
vault operator raft snapshot save /tmp/before.snap
echo "snapshot: $(ls -lh /tmp/before.snap | awk '{print $5}')"

vault kv put meridian/restore-test v=after-snapshot >/dev/null
echo "now: $(vault kv get -field=v meridian/restore-test)"

vault operator raft snapshot restore /tmp/before.snap
sleep 2
echo "after restore: $(vault kv get -field=v meridian/restore-test)"

echo
echo "A snapshot is encrypted. Restoring it needs the same seal - so the"
echo "unseal keys are part of the backup, and they usually live somewhere"
echo "else, held by somebody else. A snapshot alone is not a backup."
