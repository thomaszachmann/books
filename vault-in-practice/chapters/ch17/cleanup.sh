#!/usr/bin/env bash
# Chapter 17 - remove what the three mechanisms created.
#
# Worth watching: a controller that leaves orphaned Secrets behind after
# its resource is deleted is a real failure mode.
set -uo pipefail

kubectl delete -f manifests/vso.yaml --ignore-not-found
kubectl delete -f manifests/eso.yaml --ignore-not-found
kubectl delete -f manifests/injector-deployment.yaml --ignore-not-found
sleep 5
echo
echo "remaining Secrets in production:"
kubectl -n production get secrets --field-selector type=Opaque
