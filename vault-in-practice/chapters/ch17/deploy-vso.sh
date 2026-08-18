#!/usr/bin/env bash
# Chapter 17 - Vault Secrets Operator. Produces a Kubernetes Secret.
set -euo pipefail
cd "$(dirname "$0")"

helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null
helm upgrade --install vault-secrets-operator \
  hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator-system --create-namespace \
  --wait --timeout 3m

kubectl apply -f manifests/vso.yaml
sleep 10

echo
echo "the Secret VSO created:"
kubectl -n production get secret tracking-db \
  -o jsonpath='{.data.db_password}' | base64 -d
echo
echo
echo "note: that value is readable by anyone with 'get secret' here."
