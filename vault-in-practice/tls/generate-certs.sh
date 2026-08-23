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

# 0644, nicht 0600 - und das ist eine bewusste Labor-Konzession.
#
# Vault laeuft im Container als UID 100 ("vault"). Die Datei hier
# gehoert dem aufrufenden Host-Benutzer. Bei 0600 kann der
# Container sie nicht lesen und Vault startet gar nicht erst:
#
#   Error initializing listener of type tcp: error loading TLS
#   cert: open /vault/tls/vault-key.pem: permission denied
#
# Auf macOS mit Docker Desktop faellt das nicht auf, weil dessen
# Dateifreigabe die Eigentuemer umschreibt. Auf Linux - also auf
# jedem Host, der einem Server aehnelt - scheitert es.
#
# Dieser Schluessel ist selbstsigniert, lokal erzeugt und lebt in
# einem Wegwerf-Labor. In Produktion gehoert er 0600 und dem
# Benutzer, unter dem Vault laeuft; Kapitel 24 fuehrt das als
# Punkt in der Checkliste.
chmod 644 vault-key.pem

echo "Generated vault-cert.pem and vault-key.pem"
openssl x509 -in vault-cert.pem -noout -text \
  | grep -A1 "Subject Alternative Name"
