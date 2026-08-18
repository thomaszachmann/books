#!/usr/bin/env bash
# Chapter 2, steps 5 and 6. A root CA and a server certificate for the
# registry, with a Subject Alternative Name - which is the only field a
# Go client reads. Docker, containerd, Harbor and Kubernetes are all Go
# clients, so a certificate without a SAN has no name at all.
#
#   ./make-certs.sh 192.168.64.7 [hostname]
set -euo pipefail

IP="${1:?the IP address of the VM, from: multipass info harbor}"
HOST="${2:-harbor.meridian.test}"
ORG="Meridian Freight"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/certs"
mkdir -p "$OUT"
cd "$OUT"

if [ -f ca.key ]; then
  echo "Reusing the existing root CA. Delete certs/ca.* to start over."
else
  echo "== root CA, ten years"
  openssl genrsa -out ca.key 4096 2>/dev/null
  openssl req -x509 -new -nodes -sha256 -days 3650 \
    -key ca.key -out ca.crt \
    -subj "/O=$ORG/CN=Meridian Lab Root CA"
fi

echo "== server certificate for $HOST ($IP)"
BASE="${HOST%%.*}"
openssl genrsa -out "$BASE.key" 4096 2>/dev/null
openssl req -new -sha256 -key "$BASE.key" -out "$BASE.csr" \
  -subj "/O=$ORG/CN=$HOST"

cat > "$BASE.ext" <<EXT
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt

[alt]
DNS.1=$HOST
IP.1=$IP
EXT

openssl x509 -req -sha256 -days 365 \
  -in "$BASE.csr" -CA ca.crt -CAkey ca.key -CAcreateserial \
  -extfile "$BASE.ext" -out "$BASE.crt" 2>/dev/null

echo
echo "== verifying the name landed in the SAN"
if ! openssl x509 -noout -text -in "$BASE.crt" \
     | grep -A1 'Subject Alternative Name' | grep -q "DNS:$HOST"; then
  echo "SAN missing or wrong. Nothing downstream will work." >&2
  exit 1
fi
openssl x509 -noout -text -in "$BASE.crt" \
  | grep -A1 'Subject Alternative Name'

echo
openssl verify -CAfile ca.crt "$BASE.crt"
echo
echo "Written to $OUT:"
echo "  ca.crt      install into every trust store"
echo "  $BASE.crt  present from the registry"
echo "  $BASE.key  keep it on the server only"
