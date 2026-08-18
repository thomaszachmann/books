#!/usr/bin/env bash
# Chapter 14 - the application side.
#
# Run this twice with the same token. The second run fails, which is what
# an application would report if somebody had read the token first.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"

WRAPPED="${1:?usage: consume-secret-id.sh <wrapping-token>}"

# Check the envelope before opening it. A lookup does not consume.
PATH_IN=$(VAULT_TOKEN="$WRAPPED" vault write -field=creation_path \
  sys/wrapping/lookup token="$WRAPPED" 2>/dev/null) || {
    echo "FAIL: wrapping token invalid, expired, or already used." >&2
    echo "Treat the SecretID as compromised and reissue." >&2
    exit 1
  }

EXPECTED="auth/approle/role/tracking/secret-id"
if [ "$PATH_IN" != "$EXPECTED" ]; then
  echo "FAIL: envelope contains $PATH_IN, expected $EXPECTED" >&2
  exit 1
fi

SECRET_ID=$(VAULT_TOKEN="$WRAPPED" vault unwrap -field=secret_id)
ROLE_ID=$(vault read -field=role_id auth/approle/role/tracking/role-id)

vault write -field=token auth/approle/login \
  role_id="$ROLE_ID" secret_id="$SECRET_ID"
