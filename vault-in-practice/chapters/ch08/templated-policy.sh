#!/usr/bin/env bash
# Chapter 8, Step 9 - {{identity.entity.name}} in a policy path.
#
# One policy, correct for every entity, no per-person maintenance.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

ROOT="$VAULT_TOKEN"
EID=$(vault read -field=id identity/entity/name/alice) || {
  echo "No entity 'alice'. Run ./chapters/ch08/setup-identity.sh first."; exit 1; }

vault write identity/entity/id/"$EID" \
  policies="entity-alice,personal-space" >/dev/null

T=$(VAULT_TOKEN='' vault login -field=token -method=userpass -path=login-a \
      username=alice password=lab-a)

echo "==> writing to the entity's own path (expect: ok)"
VAULT_TOKEN="$T" vault kv put meridian/personal/alice note=written-by-me >/dev/null \
  && echo "    ok"

echo "==> writing to somebody else's path (expect: refused)"
if VAULT_TOKEN="$T" vault kv put meridian/personal/bob note=should-fail >/dev/null 2>&1; then
  echo "    UNEXPECTED: the write succeeded"
else
  echo "    refused, as intended"
fi

echo
echo "The path was never written out per person. The template resolved it"
echo "per token, at request time, from the entity behind the login."
VAULT_TOKEN="$ROOT" vault policy read personal-space
