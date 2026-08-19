#!/usr/bin/env bash
# Chapter 7, Step 4 - secret_id_num_uses=2, so the third login fails.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

ROLE_ID=$(vault read -field=role_id auth/approle/role/tracking/role-id)
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/tracking/secret-id)

echo "RoleID:   $ROLE_ID   (stable - fetch it again, same value)"
echo "SecretID: $SECRET_ID   (fresh every time)"
echo

for i in 1 2 3; do
  echo "==> login $i of 3"
  if T=$(vault write -field=token auth/approle/login \
           role_id="$ROLE_ID" secret_id="$SECRET_ID" 2>&1); then
    echo "    ok, token ...${T: -8}"
    [ "$i" = 1 ] && FIRST="$T"
  else
    echo "    refused: $(echo "$T" | grep -o 'invalid secret id' || echo "$T" | tail -1)"
  fi
done

echo
echo "The SecretID is spent. The token from login 1 is not:"
VAULT_TOKEN="${FIRST:-}" vault token lookup -format=json 2>/dev/null \
  | grep -E '"ttl"|"policies"' \
  || echo "  (no token captured)"
echo
echo "Exhausting a SecretID stops new logins. It revokes nothing."
echo
echo "SecretIDs have accessors and can be revoked one at a time:"
echo "  vault list auth/approle/role/tracking/secret-id-accessors"
