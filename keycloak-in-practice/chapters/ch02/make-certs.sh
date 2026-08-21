#!/usr/bin/env bash
# Chapter 2, steps 4 to 6: a root CA and a certificate for Keycloak.
#
# Idempotent. If pki/ca.crt exists it is reused, because the root is
# installed in four trust stores and reissuing it means redoing all four.
# `make clean-pki` is the way to start over deliberately.
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p pki && cd pki

ORG="Meridian Freight"

if [ -f ca.crt ] && [ -f ca.key ]; then
  echo "root CA: reusing pki/ca.crt"
else
  echo "root CA: creating"
  openssl genrsa -out ca.key 4096 2>/dev/null
  openssl req -x509 -new -nodes -sha256 -days 1825 \
    -key ca.key -out ca.crt \
    -subj "/O=$ORG/CN=Meridian Lab Root CA"
fi

# One leaf per name. Chapter 2 issues sso; Chapter 12 needs dc.
issue() {
  local name="$1"
  if [ -f "$name.crt" ]; then
    echo "$name: reusing pki/$name.crt"
    return
  fi
  echo "$name: issuing"
  cat > "$name.ext" <<EXT
subjectAltName=DNS:$name.meridian.test
extendedKeyUsage=serverAuth
EXT
  openssl genrsa -out "$name.key" 4096 2>/dev/null
  openssl req -new -sha256 -key "$name.key" -out "$name.csr" \
    -subj "/O=$ORG/CN=$name.meridian.test"
  openssl x509 -req -sha256 -days 365 -in "$name.csr" \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -extfile "$name.ext" -out "$name.crt" 2>/dev/null
}

issue sso
issue dc

echo
echo "Subject Alternative Names, which is the field that matters:"
for c in sso dc; do
  printf '  %s: ' "$c"
  openssl x509 -in "$c.crt" -noout -ext subjectAltName \
    | tail -1 | sed 's/^ *//'
done

cat <<'NEXT'

Next: install pki/ca.crt into your operating system trust store AND
into Firefox, which keeps its own. Chapter 2, step 6.
NEXT
