#!/usr/bin/env bash
# Upgrade von Envoy Gateway in der richtigen Reihenfolge (Tag 12).
# Aufruf: upgrade-eg.sh <version> [--apply]   ohne --apply nur Diff
set -euo pipefail
V="${1:?Version, z. B. v1.9.2}"; MODE="${2:-}"
C=~/gw-lab/code
crds() {
  helm template eg-crds oci://docker.io/envoyproxy/gateway-crds-helm \
    --version "$V" --set crds.gatewayAPI.enabled=true \
    --set crds.gatewayAPI.channel=experimental \
    --set crds.envoyGateway.enabled=true
}
echo "== 1. CRD-Diff"
crds | kubectl diff --server-side --force-conflicts -f - \
  | grep -E '^[-+] +gateway.networking.k8s.io/bundle-version' | sort | uniq -c || true
[ "$MODE" = "--apply" ] || { echo "(nur Diff, --apply zum Ausführen)"; exit 0; }
echo "== 2. CRDs anwenden (vor dem Controller!)"
crds | kubectl apply --server-side --force-conflicts -f - | grep -v unchanged || true
echo "== 3. Controller"
helm upgrade eg oci://docker.io/envoyproxy/gateway-helm --version "$V" \
  -n envoy-gateway-system -f $C/tag10/eg-values.yaml \
  -f $C/tag12/eg-ha-values.yaml --wait
kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway
echo "== 4. Proxys rollen nach (neues Envoy-Image)"
kubectl -n envoy-gateway-system rollout status deploy \
  -l gateway.envoyproxy.io/owning-gateway-name=web --timeout=5m
