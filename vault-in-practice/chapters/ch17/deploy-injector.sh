#!/usr/bin/env bash
# Chapter 17 - Agent Injector. The secret becomes a file on tmpfs inside
# the pod and never becomes a Kubernetes object.
set -euo pipefail
cd "$(dirname "$0")"

kubectl apply -f manifests/injector-deployment.yaml
kubectl -n production rollout status deploy/tracking --timeout=120s

POD=$(kubectl -n production get pod -l app=tracking \
  -o jsonpath='{.items[0].metadata.name}')

echo
echo "containers in the pod you declared with one:"
kubectl -n production get pod "$POD" \
  -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}'
echo
echo
echo "the rendered secret:"
kubectl -n production exec "$POD" -c app -- cat /vault/secrets/db
echo
echo "and where it lives:"
kubectl -n production exec "$POD" -c app -- mount | grep vault/secrets
