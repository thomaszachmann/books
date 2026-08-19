#!/usr/bin/env bash
# Remove everything this book created. Appendix H.
#
# reset-lab.sh wipes Vault's data and starts again.
# teardown.sh removes containers, volumes, certificates and clusters.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "This removes:"
echo "  - all containers from both compose files, with their volumes"
echo "  - Vault data, Raft state, audit logs and init.json"
echo "  - the three-node cluster from Chapter 21"
echo "  - the generated TLS certificate"
echo "  - the offline root CA from Chapter 13"
echo "  - the SSH CA from Chapter 19"
echo "  - the kind and minikube clusters from Chapters 16-18"
echo
read -r -p "Type TEARDOWN to continue: " confirm
[ "$confirm" = "TEARDOWN" ] || { echo "Aborted."; exit 1; }

docker compose down -v --remove-orphans 2>/dev/null || true
docker compose -f docker-compose.cluster.yml down -v 2>/dev/null || true
rm -rf data/* logs/* raft cluster init.json init-backup.json root-ca
rm -rf chapters/ch19/ssh-ca
rm -f tls/*.pem tls/*.srl

if command -v kind >/dev/null 2>&1; then
  kind delete cluster --name vault-lab 2>/dev/null || true
fi
if command -v minikube >/dev/null 2>&1; then
  minikube delete --profile vault-lab 2>/dev/null || true
fi

echo
echo "Gone. To start over:  make tls && make up && make init && make unseal"
