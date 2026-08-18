#!/usr/bin/env bash
# Chapter 19 - generate a keypair, have Vault sign it, log in.
#
# The private key never leaves this machine. Vault signs a public key and
# never sees the private half.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first}"

KEY=/tmp/lab-key
[ -f "$KEY" ] || ssh-keygen -t ed25519 -f "$KEY" -N "" -C "lab@meridian"

vault write -field=signed_key ssh/sign/ops \
  public_key=@"$KEY.pub" \
  valid_principals="ubuntu" > "$KEY-cert.pub"

# vault write -field= writes whatever it gets, including an error.
head -c 30 "$KEY-cert.pub" | grep -q '^ssh-' || {
  echo "signing failed:" >&2; cat "$KEY-cert.pub" >&2; exit 1; }

echo "=== the certificate ==="
ssh-keygen -Lf "$KEY-cert.pub"

echo
echo "=== logging in ==="
ssh -i "$KEY" -o CertificateFile="$KEY-cert.pub" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -p 2222 ubuntu@127.0.0.1 'echo "logged in to $(hostname)"'

echo
echo "Wait two minutes and run this login again - it fails, and nothing"
echo "was revoked. That is the whole argument for certificates."
