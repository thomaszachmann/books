#!/usr/bin/env bash
# Chapter 3 - every error the chapter prints, on purpose.
#
# This one is different: it needs an UNINITIALISED Vault, which a
# development server can never be. Run it against the lab from Chapter 2,
# before 'make init':
#
#   make up
#   ./chapters/ch03/reproduce-errors.sh
#
# It initialises with its own shares, breaks things deliberately, and
# leaves the Vault initialised and unsealed - which is where Chapter 3's
# lab wants it anyway.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
case "$VAULT_ADDR" in
  https://*) export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}" ;;
  *)         unset VAULT_CACERT ;;
esac
command -v jq >/dev/null || { echo "jq required"; exit 1; }

wwr_case "invalid seal configuration: threshold cannot be larger than shares"
echo "Asked for 3 of 2, which is not a thing:"
wwr_expect "threshold cannot be larger than shares" vault operator init -key-shares=2 -key-threshold=3

if vault status -format=json 2>/dev/null | jq -e '.initialized' >/dev/null; then
  echo
  echo "This Vault is already initialised, so the cases below cannot run."
  echo "They need a Vault that has never been initialised: 'make reset',"
  echo "then 'make up', then this script before 'make init'."
  exit 0
fi

INIT=/tmp/wwr-init.json
vault operator init -format=json -key-shares=5 -key-threshold=3 > "$INIT"
chmod 600 "$INIT"
k() { jq -r ".unseal_keys_b64[$1]" "$INIT"; }

wwr_case "Vault is already initialized"
wwr_expect "already initialized" vault operator init -key-shares=5 -key-threshold=3
echo "Somebody ran it before - possibly you, in a previous attempt."

wwr_case "invalid key: key is shorter than minimum 16 bytes"
echo "Cause 1: the key was truncated on copy. They are long and wrap."
wwr_expect "shorter than minimum 16 bytes" vault operator unseal "$(k 0 | cut -c1-20)"
echo
echo "Cause 2: the same key supplied twice counts once."
vault operator unseal "$(k 0)" >/dev/null
echo "  after key 1:  $(vault status -format=json | jq -r '"Unseal Progress \(.progress)/\(.t)"')"
vault operator unseal "$(k 0)" >/dev/null 2>&1 || true
echo "  same key again: $(vault status -format=json | jq -r '"Unseal Progress \(.progress)/\(.t)"')"

wwr_case "Unseal Progress 2/3 and nothing happens"
vault operator unseal "$(k 1)" >/dev/null
echo "  after a second DISTINCT key: $(vault status -format=json | jq -r '"Unseal Progress \(.progress)/\(.t)"')"
echo "Progress counts distinct keys. Two is not three, and nothing will"
echo "happen until the third arrives:"
vault operator unseal "$(k 2)" >/dev/null
echo "  after the third: Sealed $(vault status -format=json | jq -r '.sealed')"

wwr_case "Error making API request ... 503 after a restart"
export VAULT_TOKEN
VAULT_TOKEN=$(jq -r .root_token "$INIT")
vault secrets enable -path=wwr3 -version=2 kv >/dev/null 2>&1 || true
vault kv put wwr3/x a=b >/dev/null
vault operator seal >/dev/null
echo "Sealed, as a restart would leave it. Now read something:"
wwr_run vault kv get wwr3/x
code=$(curl -s -o /dev/null -w '%{http_code}' \
        -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/wwr3/data/x")
printf '  over HTTP that is: %s\n' "$code"
echo "This is correct behaviour, not a fault. 503 is Vault, 403 is you."
for i in 0 1 2; do vault operator unseal "$(k $i)" >/dev/null; done
echo "  unsealed again: Sealed $(vault status -format=json | jq -r '.sealed')"

echo
echo "Keys and root token for this run are in $INIT"
wwr_done
