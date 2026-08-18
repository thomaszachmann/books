#!/usr/bin/env bash
# Self-signed certificate for the lab. Chapter 2.
#
# The IP SAN is the part that matters: modern TLS clients ignore the
# Common Name entirely and validate against Subject Alternative Names.
set -euo pipefail

cd "$(dirname "$0")"

if [ -f vault-cert.pem ] && [ "${1:-}" != "--force" ]; then
  echo "Certificate already exists. Use --force to regenerate."
  exit 0
fi

openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
  -keyout vault-key.pem -out vault-cert.pem \
  -subj "/CN=vault.lab.local" \
  -addext "subjectAltName=DNS:vault.lab.local,DNS:vault,DNS:localhost,IP:127.0.0.1"

chmod 644 vault-cert.pem
chmod 600 vault-key.pem

echo "Generated vault-cert.pem and vault-key.pem"
openssl x509 -in vault-cert.pem -noout -text \
  | grep -A1 "Subject Alternative Name"
