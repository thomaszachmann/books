#!/usr/bin/env bash
# Tag 7, Drill 4 - Befehle wörtlich aus dem Buch.
cat > openbao.ext <<'EOF'
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = openbao
DNS.2 = openbao-active
DNS.3 = *.openbao-internal
DNS.4 = *.openbao-internal.openbao.svc.cluster.local
DNS.5 = openbao.openbao.svc
DNS.6 = openbao-0.openbao-internal
DNS.7 = openbao-1.openbao-internal
DNS.8 = openbao-2.openbao-internal
DNS.9 = localhost
IP.1 = 127.0.0.1
EOF
openssl req -newkey rsa:2048 -nodes -keyout tls.key -out tls.csr \
  -subj "/CN=openbao"
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out tls.crt -days 180 -sha256 -extfile openbao.ext
