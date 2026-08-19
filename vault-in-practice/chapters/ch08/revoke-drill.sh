#!/usr/bin/env bash
# Chapter 8, Step 8 - disable the entity, watch both logins close.
#
# Note what this does NOT do: tokens already issued keep working until
# they expire. For an incident, disable the entity AND revoke the
# outstanding tokens by accessor.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"
command -v jq >/dev/null || { echo "jq is required - see Appendix A"; exit 1; }

ROOT="$VAULT_TOKEN"
EID=$(vault read -field=id identity/entity/name/alice) || {
  echo "No entity 'alice'. Run ./chapters/ch08/setup-identity.sh first."; exit 1; }

try_login() {
  local path="$1" user="$2" pw="$3"
  local out
  if out=$(VAULT_TOKEN='' vault login -method=userpass -path="$path" \
             username="$user" password="$pw" 2>&1); then
    echo "  $path/$user: allowed"
  else
    echo "  $path/$user: refused - $(echo "$out" | grep -o 'entity is disabled' \
      || echo "$out" | tail -1 | sed 's/^ *//')"
  fi
}

echo "==> both logins, entity enabled"
try_login login-a alice      lab-a
try_login login-b p.raghavan lab-b

echo
echo "==> disabling entity $EID"
vault write identity/entity/id/"$EID" disabled=true >/dev/null
try_login login-a alice      lab-a
try_login login-b p.raghavan lab-b

echo
echo "One flag closed both doors."
echo
echo "==> re-enabling"
VAULT_TOKEN="$ROOT" vault write identity/entity/id/"$EID" disabled=false >/dev/null
try_login login-a alice lab-a
