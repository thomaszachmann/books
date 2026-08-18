#!/usr/bin/env bash
# Chapter 13 - offline root, intermediate in Vault, a 24h role.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

CA=root-ca
mkdir -p "$CA"

# 1. Root CA - deliberately outside Vault
if [ ! -f "$CA/root-ca.crt" ]; then
  echo "==> generating offline root CA"
  openssl genrsa -out "$CA/root-ca.key" 4096 2>/dev/null
  openssl req -x509 -new -sha256 -days 3650 \
    -key "$CA/root-ca.key" -out "$CA/root-ca.crt" \
    -subj "/C=DE/O=Meridian Freight/CN=Meridian Root CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"
else
  echo "==> root CA already present"
fi

# 2. Intermediate mount
vault secrets enable -path=pki_int pki 2>/dev/null \
  || echo "==> pki_int already enabled"
vault secrets tune -max-lease-ttl=43800h pki_int >/dev/null

# 3. CSR from Vault - the private key never leaves
echo "==> generating intermediate CSR"
vault write -field=csr pki_int/intermediate/generate/internal \
  common_name="Meridian Intermediate CA" key_bits=4096 \
  > "$CA/pki_int.csr"

# 4. Sign it with the offline root
cat > "$CA/int-ext.cnf" <<'CNF'
basicConstraints     = critical,CA:TRUE,pathlen:0
keyUsage             = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
CNF

openssl x509 -req -in "$CA/pki_int.csr" \
  -CA "$CA/root-ca.crt" -CAkey "$CA/root-ca.key" -CAcreateserial \
  -out "$CA/pki_int.crt" -days 1825 -sha256 \
  -extfile "$CA/int-ext.cnf" 2>/dev/null

# 5. Import the full chain, not just the intermediate
cat "$CA/pki_int.crt" "$CA/root-ca.crt" > "$CA/pki_int-chain.crt"
vault write pki_int/intermediate/set-signed \
  certificate=@"$CA/pki_int-chain.crt" >/dev/null

# 6. Distribution points
vault write pki_int/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/pki_int/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/pki_int/crl" >/dev/null

# 7. The role - this is the security boundary, not the policy
vault write pki_int/roles/meridian-24h \
  allowed_domains="meridian.internal" \
  allow_subdomains=true \
  allow_bare_domains=false \
  max_ttl="24h" ttl="24h" \
  key_type="rsa" key_bits=2048 >/dev/null

vault policy write pki-issue chapters/ch13/policies/pki-issue.hcl

echo
echo "Done. Issue a certificate:"
echo "  vault write pki_int/issue/meridian-24h \\"
echo "    common_name=api.meridian.internal ttl=24h"
echo
echo "Watch the role refuse a name it does not own:"
echo "  vault write pki_int/issue/meridian-24h \\"
echo "    common_name=login.microsoftonline.com ttl=1h"
