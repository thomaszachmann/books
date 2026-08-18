#!/usr/bin/env bash
# Chapter 21 - a three-node Raft cluster.
#
# Self-contained: its own certificates, configs and data directories, so
# the single-node lab from Chapter 2 stays untouched.
set -euo pipefail
cd "$(dirname "$0")/../.."

C=cluster
mkdir -p $C/tls $C/config $C/data1 $C/data2 $C/data3
chmod 777 $C/data1 $C/data2 $C/data3

# 1. A certificate naming all three nodes. The Chapter 2 cert does not,
#    and TLS refuses - the most common failure when building a cluster.
if [ ! -f $C/tls/cert.pem ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
    -keyout $C/tls/key.pem -out $C/tls/cert.pem \
    -subj "/CN=vault-cluster" \
    -addext "subjectAltName=DNS:vault-1,DNS:vault-2,DNS:vault-3,DNS:localhost,IP:127.0.0.1"
  chmod 644 $C/tls/cert.pem; chmod 644 $C/tls/key.pem
fi

# 2. One config per node. node_id must be unique - copying a config
#    without editing it is how clusters lose members.
for n in 1 2 3; do
  cat > $C/config/vault-$n.hcl <<CFG
ui            = true
disable_mlock = true

storage "raft" {
  path    = "/vault/data"
  node_id = "vault-$n"

  retry_join {
    leader_api_addr     = "https://vault-1:8200"
    leader_ca_cert_file = "/vault/tls/cert.pem"
  }
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/cert.pem"
  tls_key_file  = "/vault/tls/key.pem"
}

api_addr     = "https://vault-$n:8200"
cluster_addr = "https://vault-$n:8201"
CFG
done

docker compose -f docker-compose.cluster.yml up -d
sleep 6

export VAULT_CACERT="$PWD/$C/tls/cert.pem"
export VAULT_ADDR='https://127.0.0.1:8210'

if [ ! -f $C/init.json ]; then
  vault operator init -key-shares=1 -key-threshold=1 \
    -format=json > $C/init.json
  chmod 600 $C/init.json
fi
UK=$(jq -r '.unseal_keys_b64[0]' $C/init.json)

# Every node has its own root key in its own memory. Three nodes, three
# unseal operations - the argument for Chapter 22 in one loop.
for p in 8210 8220 8230; do
  VAULT_ADDR="https://127.0.0.1:$p" vault operator unseal "$UK" >/dev/null
done
sleep 3

export VAULT_TOKEN=$(jq -r '.root_token' $C/init.json)
vault operator raft list-peers

echo
echo "health codes a load balancer would see:"
for p in 8210 8220 8230; do
  printf "  %s: " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" \
    --cacert "$VAULT_CACERT" "https://127.0.0.1:$p/v1/sys/health"
done
echo
echo "Accept only 200. Anything treating 429 as healthy sends traffic to"
echo "standbys, which forward it - a hop that hides behind low latency."
echo
echo "export VAULT_CACERT=$PWD/$C/tls/cert.pem"
echo "export VAULT_ADDR=https://127.0.0.1:8210"
echo "export VAULT_TOKEN=\$(jq -r .root_token $C/init.json)"
