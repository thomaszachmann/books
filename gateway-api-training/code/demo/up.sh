#!/usr/bin/env bash
# Baut das Lab auf den Stand nach Tag 2: kind-Cluster, Envoy Gateway,
# Demo-Apps, GatewayClass eg, Gateway infra/web, HTTPRoute shop/shop.
# cloud-provider-kind muss in einem zweiten Terminal laufen (Tag 0).
set -euo pipefail
cd "$(dirname "$0")"
CLUSTER="${CLUSTER:-gw-lab}"
EG_VERSION="${EG_VERSION:-v1.9.2}"

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --config kind-gw-lab.yaml
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "$EG_VERSION" -n envoy-gateway-system --create-namespace --wait
kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available

kubectl apply -f namespaces.yaml
kubectl apply -f shop-v1.yaml -f shop-v2.yaml -f payments.yaml
kubectl apply -f gatewayclass.yaml -f gateway.yaml -f route-shop.yaml

kubectl -n shop rollout status deploy/shop-v1 --timeout=3m
kubectl -n shop rollout status deploy/shop-v2 --timeout=3m
kubectl -n payments rollout status deploy/payments --timeout=3m
kubectl -n infra wait gateway/web --for=condition=Programmed --timeout=3m
echo "GW_IP=$(./gw-ip.sh)"
