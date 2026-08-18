#!/usr/bin/env bash
# Chapter 16 - a local cluster with Vault installed.
set -euo pipefail

FLAVOUR="${1:-kind}"
NAME=vault-lab

case "$FLAVOUR" in
  kind)
    kind get clusters 2>/dev/null | grep -qx "$NAME" \
      || kind create cluster --name "$NAME"
    kubectl config use-context "kind-$NAME"
    ;;
  minikube)
    minikube status -p "$NAME" >/dev/null 2>&1 \
      || minikube start -p "$NAME"
    kubectl config use-context "$NAME"
    ;;
  *)
    echo "usage: cluster-up.sh [kind|minikube]" >&2; exit 1 ;;
esac

kubectl get nodes

helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null
helm repo update >/dev/null

# dev mode: unsealed, in-memory, root token "root".
# A lab shortcut and nothing else - Chapter 21 deploys it properly.
helm upgrade --install vault hashicorp/vault \
  --namespace vault --create-namespace \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true" \
  --wait --timeout 3m

kubectl -n vault get pods
echo
echo "Next: ./setup-k8s-auth.sh"
