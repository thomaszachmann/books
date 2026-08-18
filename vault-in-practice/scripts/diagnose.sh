#!/usr/bin/env bash
# Work out why the lab is not doing what you expect. Appendix G.
#
# Runs the checks in the order the book's "What Went Wrong" sections
# suggest: is it running, is it reachable, is it sealed, is the token
# valid, does the policy permit what you are attempting.
set -uo pipefail
cd "$(dirname "$0")/.."

pass() { printf "  \033[0;32mok\033[0m    %s\n" "$1"; }
fail() { printf "  \033[0;31mFAIL\033[0m  %s\n" "$1"; }
info() { printf "        %s\n" "$1"; }

echo "Vault lab diagnosis"
echo

# 1. Container
if docker compose ps --status running 2>/dev/null | grep -q vault; then
  pass "container running"
else
  fail "container not running"
  info "fix: docker compose up -d vault"
  info "then: docker compose logs vault --tail 20"
  exit 1
fi

# 2. Environment
ADDR="${VAULT_ADDR:-}"
if [ -z "$ADDR" ]; then
  fail "VAULT_ADDR is not set"
  info "the CLI default is https://127.0.0.1:8200 - correct here,"
  info "but set it explicitly:  make env"
  ADDR="https://127.0.0.1:8200"
else
  pass "VAULT_ADDR=$ADDR"
fi

CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
if [ -f "$CACERT" ]; then
  pass "CA certificate present"
else
  fail "no CA certificate at $CACERT"
  info "fix: make tls"
fi

# 3. Reachable
if ! curl -sf --cacert "$CACERT" "$ADDR/v1/sys/seal-status" \
     -o /tmp/seal.json 2>/dev/null; then
  fail "cannot reach $ADDR"
  info "scheme mismatch? the lab serves https, the dev server http"
  info "certificate not trusted? export VAULT_CACERT=$PWD/tls/vault-cert.pem"
  exit 1
fi
pass "API reachable"

# 4. Initialised and sealed
INIT=$(jq -r '.initialized' /tmp/seal.json)
SEALED=$(jq -r '.sealed' /tmp/seal.json)
PROGRESS=$(jq -r '"\(.progress)/\(.t)"' /tmp/seal.json)

if [ "$INIT" != "true" ]; then
  fail "not initialised"
  info "fix: make init && make unseal"
  exit 1
fi
pass "initialised"

if [ "$SEALED" = "true" ]; then
  fail "SEALED (unseal progress $PROGRESS)"
  info "every request returns 503 until this is fixed"
  info "fix: make unseal"
  exit 1
fi
pass "unsealed"

# 5. Token
if [ -z "${VAULT_TOKEN:-}" ] && [ ! -f ~/.vault-token ]; then
  fail "no token in VAULT_TOKEN and no ~/.vault-token"
  info "fix: export VAULT_TOKEN=\$(jq -r .root_token init.json)"
  exit 1
fi

if vault token lookup >/dev/null 2>&1; then
  TTL=$(vault token lookup -format=json | jq -r '.data.ttl')
  POL=$(vault token lookup -format=json | jq -r '.data.policies | join(",")')
  pass "token valid (ttl ${TTL}s, policies: $POL)"
else
  fail "token rejected"
  info "expired, revoked, or its parent was revoked"
  info "note: VAULT_TOKEN outranks ~/.vault-token - unset it and retry"
  exit 1
fi

# 6. Optional path check
if [ $# -ge 1 ]; then
  echo
  echo "Capabilities at $1:"
  vault token capabilities "$1" 2>&1 | sed 's/^/  /'
  case "$1" in
    */data/*|*/metadata/*) ;;
    *) info "note: for kv-v2 use the API path, e.g. secret/data/$1" ;;
  esac
fi

echo
echo "No problems found."
echo "Pass an API path to check permissions:"
echo "  ./scripts/diagnose.sh secret/data/myapp"
