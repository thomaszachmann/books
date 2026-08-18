#!/usr/bin/env bash
# Chapter 14 - the operator side. Emits ONLY a wrapping token.
#
# The SecretID itself never appears here, so it cannot end up in a build
# log. What can end up in a log is a token that expires in two minutes and
# whose reuse is detectable.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first}"

TTL="${1:-120s}"

vault write -wrap-ttl="$TTL" -f -field=wrapping_token \
  auth/approle/role/tracking/secret-id
