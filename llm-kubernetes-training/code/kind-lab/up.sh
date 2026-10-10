#!/usr/bin/env bash
# Baut den kind-Cluster "ki-lab" komplett auf (idempotent).
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ki-lab
CTX=kind-$CLUSTER
INGRESS_VERSION=controller-v1.15.1
METRICS_CHART=3.14.0
GH=https://raw.githubusercontent.com/kubernetes/ingress-nginx

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --config kind-config.yaml
fi
kubectl config use-context "$CTX" >/dev/null
kubectl apply -f namespaces.yaml

kubectl apply -f "$GH/$INGRESS_VERSION/deploy/static/provider/kind/deploy.yaml"
kubectl -n ingress-nginx patch deployment ingress-nginx-controller \
  --type merge -p '{"spec":{"template":{"spec":{"nodeSelector":
  {"ingress-ready":"true","kubernetes.io/os":"linux"}}}}}'
kubectl -n ingress-nginx rollout status deployment ingress-nginx-controller \
  --timeout=180s

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ \
  --force-update >/dev/null
helm upgrade --install metrics-server metrics-server/metrics-server \
  --version "$METRICS_CHART" -n kube-system \
  --set 'args={--kubelet-insecure-tls}' --wait

[ "${PRELOAD:-1}" = 1 ] && ./preload.sh

echo "✔ Cluster $CLUSTER bereit (Kontext $CTX)"
