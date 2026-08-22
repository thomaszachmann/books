#!/usr/bin/env bash
# Generate certificates, configs and data directories, then start three
# nodes. Idempotent: existing certificates and configs are left alone.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

C=cluster
mkdir -p "$C/tls" "$C/config" "$C/data1" "$C/data2" "$C/data3" logs
chmod 777 "$C/data1" "$C/data2" "$C/data3"

# One certificate naming all three nodes. A certificate that names only
# one is the most common reason a first cluster refuses to form.
if [ ! -f "$C/tls/cert.pem" ]; then
  echo "==> generating a certificate for vault-1, vault-2, vault-3"
  openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
    -keyout "$C/tls/key.pem" -out "$C/tls/cert.pem" \
    -subj "/CN=vault-cluster" \
    -addext "subjectAltName=DNS:vip-vault-1,DNS:vip-vault-2,DNS:vip-vault-3,DNS:localhost,IP:127.0.0.1" \
    2>/dev/null
  chmod 644 "$C/tls/cert.pem" "$C/tls/key.pem"
fi

# One config per node. node_id must be unique; copying a config without
# editing it is how a cluster silently loses a member.
for n in 1 2 3; do
  [ -f "$C/config/vault-$n.hcl" ] && continue
  cat > "$C/config/vault-$n.hcl" <<CFG
ui            = true
disable_mlock = true

storage "raft" {
  path    = "/vault/data"
  node_id = "vault-$n"

  retry_join { leader_api_addr = "https://vip-vault-1:8200"
               leader_ca_cert_file = "/vault/tls/cert.pem" }
  retry_join { leader_api_addr = "https://vip-vault-2:8200"
               leader_ca_cert_file = "/vault/tls/cert.pem" }
  retry_join { leader_api_addr = "https://vip-vault-3:8200"
               leader_ca_cert_file = "/vault/tls/cert.pem" }
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/cert.pem"
  tls_key_file  = "/vault/tls/key.pem"
}

api_addr     = "https://vip-vault-$n:8200"
cluster_addr = "https://vip-vault-$n:8201"
CFG
done

. ./scripts/engine.sh
echo "==> Laufzeit: $ENGINE_NAME"

$COMPOSE up -d
./scripts/wait-for-vault.sh
echo
echo "Three nodes up, uninitialised and sealed. Next:  make init && make unseal"
