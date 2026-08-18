#!/usr/bin/env bash
# Chapter 16 - remove the cluster and undo the network change.
set -uo pipefail

docker network disconnect kind vault 2>/dev/null || true
kind delete cluster --name vault-lab 2>/dev/null || true
minikube delete -p vault-lab 2>/dev/null || true
echo "Clusters removed."
