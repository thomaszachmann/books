#!/usr/bin/env bash
# Zeigt Version und Channel aller Gateway-API-CRDs (Tag 12).
set -euo pipefail
kubectl get crd -o json | jq -r '.items[]
  | select(.spec.group=="gateway.networking.k8s.io")
  | [.metadata.name,
     .metadata.annotations["gateway.networking.k8s.io/bundle-version"],
     .metadata.annotations["gateway.networking.k8s.io/channel"],
     ([.spec.versions[] | select(.served) | .name] | join(","))]
  | @tsv' | column -t
