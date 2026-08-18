#!/usr/bin/env bash
# Single source of truth for every version the labs use.
# Source this, do not copy values out of it.
#
#   . "$(dirname "$0")/versions.sh"
#   echo "$HARBOR_VERSION"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(grep -E '^[A-Z_]+=' "$ROOT/VERSIONS.md")"
export ROOT HARBOR_VERSION HARBOR_CHART_VERSION TRIVY_VERSION \
       COSIGN_VERSION KIND_VERSION MINIKUBE_VERSION HELM_VERSION \
       ESO_CHART_VERSION UBUNTU_SERIES VM_NAME VM_CPUS VM_MEMORY VM_DISK
