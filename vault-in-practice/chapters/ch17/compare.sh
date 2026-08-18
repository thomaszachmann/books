#!/usr/bin/env bash
# Chapter 17 - Marek's question: where did the secret end up, and who can
# read it there?
set -uo pipefail

echo "=== Kubernetes Secrets in production ==="
kubectl -n production get secrets \
  --field-selector type=Opaque 2>/dev/null

echo
echo "=== The injector left nothing here ==="
POD=$(kubectl -n production get pod -l app=tracking \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$POD" ]; then
  echo "file in the pod:"
  kubectl -n production exec "$POD" -c app -- \
    cat /vault/secrets/db 2>/dev/null | sed 's/^/  /'
  echo "no API call retrieves that."
fi

echo
echo "=== Who can read the Secrets ==="
for sa in default tracking; do
  printf "  serviceaccount/%-10s " "$sa"
  kubectl auth can-i get secrets -n production \
    --as="system:serviceaccount:production:$sa"
done
echo
echo "If any of those is 'yes', that account holds the database password."
echo "The built-in 'view' role includes reading Secrets - which surprises"
echo "people who granted it as read-only access."
