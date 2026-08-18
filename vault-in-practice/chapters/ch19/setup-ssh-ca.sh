#!/usr/bin/env bash
# Chapter 19 - an SSH certificate authority.
#
# The payoff: offboarding stops being a list of servers. Revoke the
# person's Vault access and their certificates simply stop being issued;
# the ones they hold expire on their own.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

vault secrets enable ssh 2>/dev/null || echo "ssh already enabled"
vault write ssh/config/ca generate_signing_key=true >/dev/null 2>&1 \
  || echo "signing key already present"

mkdir -p chapters/ch19/ssh-ca
vault read -field=public_key ssh/config/ca \
  > chapters/ch19/ssh-ca/trusted-ca.pem

# ttl is two minutes on purpose: watch a certificate expire in the lab.
# allowed_users="*" would permit a certificate for root on every server
# that trusts this CA. It is the allow_any_name of this chapter.
vault write ssh/roles/ops \
  key_type=ca \
  allow_user_certificates=true \
  allowed_users="ubuntu" \
  default_user="ubuntu" \
  default_extensions='{"permit-pty":""}' \
  ttl="2m" max_ttl="10m" >/dev/null

echo "CA public key written to chapters/ch19/ssh-ca/trusted-ca.pem"
echo
echo "Start the server, then sign a key:"
echo "  docker compose up -d sshd"
echo "  ./chapters/ch19/sign-and-login.sh"
