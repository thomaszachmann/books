#!/usr/bin/env bash
# Set up the development Vault for Part VI: the three secret engines the
# chapters use, and the three policies that bound them.
#
#   make vault-up        # starts it
#   ./vault/bootstrap.sh # this
#
# Idempotent: every step tolerates already having been done.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
VAULT_PORT="${VAULT_PORT:-8200}"
export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:$VAULT_PORT}"
export VAULT_TOKEN="${VAULT_TOKEN:-root}"

v() { docker exec -e VAULT_ADDR=http://127.0.0.1:8200 \
        -e VAULT_TOKEN="$VAULT_TOKEN" harbor-lab-vault vault "$@"; }

enable() {
  if v secrets list -format=json | jq -e --arg p "$1/" 'has($p)' >/dev/null; then
    echo "ok      $1 already enabled"
  else
    v secrets enable "$@" >/dev/null && echo "enabled $1"
  fi
}

echo "== engines"
# kv v2 is mounted at secret/ by a dev server already.
enable pki
enable transit

echo
echo "== pki (Chapter 18)"
# generate/internal happily makes a SECOND root if you call it twice,
# and the old one keeps validating nothing. Check first.
if v read pki/cert/ca >/dev/null 2>&1; then
  echo "ok      root CA already present"
else
  v write -field=certificate pki/root/generate/internal \
    common_name="Meridian Lab CA" ttl=8760h >/dev/null
  echo "generated the root CA"
fi
v write pki/roles/harbor \
  allowed_domains=meridian.test allow_subdomains=true \
  max_ttl=720h >/dev/null
echo "role    pki/roles/harbor"

echo
echo "== transit (Chapter 20)"
if v read transit/keys/harbor-signing >/dev/null 2>&1; then
  echo "ok      transit/keys/harbor-signing already exists"
else
  # exportable defaults to false and CANNOT be changed later. That
  # immutability is the guarantee - see Chapter 20.
  v write -f transit/keys/harbor-signing type=ecdsa-p256 >/dev/null
  echo "created transit/keys/harbor-signing (ecdsa-p256, not exportable)"
fi

echo
echo "== policies"
for f in "$HERE"/policies/*.hcl; do
  N="$(basename "$f" .hcl)"
  docker exec -i -e VAULT_ADDR=http://127.0.0.1:8200 \
    -e VAULT_TOKEN="$VAULT_TOKEN" harbor-lab-vault \
    vault policy write "$N" - < "$f" >/dev/null
  echo "wrote   $N"
done

echo
echo "== placeholders the chapters overwrite"
v kv put secret/harbor \
  admin_password=Harbor12345 db_password=root123 >/dev/null
echo "wrote   secret/harbor        (Chapter 18 replaces these)"
v kv put secret/harbor-pull \
  username='robot$platform+cluster-pull' password=changeme >/dev/null
echo "wrote   secret/harbor-pull   (Chapter 19 replaces these)"

cat <<TXT

Ready.

  export VAULT_ADDR=http://127.0.0.1:$VAULT_PORT
  export VAULT_TOKEN=root

Root token 'root' and no TLS: this Vault is a lab fixture. Chapter 18
explains what a real one changes, and Book One is about running it.
TXT
