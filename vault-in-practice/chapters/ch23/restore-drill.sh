#!/usr/bin/env bash
# Chapter 23 - rehearse the restore. A backup you have never restored is
# a hypothesis.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first}"

vault kv put meridian/restore-drill v=before >/dev/null
./chapters/ch23/backup-vault.sh >/dev/null
vault kv put meridian/restore-drill v=after >/dev/null
echo "before restore: $(vault kv get -field=v meridian/restore-drill)"

SNAP=$(ls -t backups/*.snap | head -1)
vault operator raft snapshot restore "$SNAP"
sleep 3
echo "after restore:  $(vault kv get -field=v meridian/restore-drill)"
echo
echo "Put this on a calendar."
