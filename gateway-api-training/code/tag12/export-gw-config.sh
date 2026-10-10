#!/usr/bin/env bash
# Exportiert Gateway-API- und Envoy-Gateway-Objekte als sauberes YAML
# (ohne status/managedFields) nach ./gitops-export (Tag 12).
set -euo pipefail
out="${1:-gitops-export}"
kinds="gatewayclasses gateways httproutes grpcroutes tlsroutes tcproutes
udproutes referencegrants backendtlspolicies listenersets
envoyproxies clienttrafficpolicies backendtrafficpolicies
securitypolicies envoyextensionpolicies backends"
mkdir -p "$out"
for k in $kinds; do
  kubectl get "$k" -A -o name >/dev/null 2>&1 || continue
  kubectl get "$k" -A -o yaml | yq '
    .items[] |= (del(.status)
      | del(.metadata.managedFields, .metadata.uid,
            .metadata.resourceVersion, .metadata.generation,
            .metadata.creationTimestamp)
      | del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration"))
    | .items' > "$out/$k.yaml"
  n=$(yq 'length' "$out/$k.yaml")
  [ "$n" = "0" ] && rm "$out/$k.yaml" || echo "$k: $n"
done
