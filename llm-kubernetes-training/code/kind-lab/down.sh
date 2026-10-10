#!/usr/bin/env bash
# Löscht den kind-Cluster "ki-lab". Modelle im PVC sind danach weg.
set -euo pipefail
kind delete cluster --name "${CLUSTER:-ki-lab}"
