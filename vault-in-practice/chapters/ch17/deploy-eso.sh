#!/usr/bin/env bash
# Chapter 17 - External Secrets Operator. Same result, vendor-neutral.
set -euo pipefail
cd "$(dirname "$0")"

helm repo add external-secrets https://charts.external-secrets.io >/dev/null
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --wait --timeout 3m

kubectl apply -f manifests/eso.yaml
sleep 15

kubectl -n production get externalsecret tracking-db-eso
echo
kubectl -n production get secret tracking-db-eso \
  -o jsonpath='{.data.password}' | base64 -d || true
echo
