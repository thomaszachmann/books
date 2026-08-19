#!/usr/bin/env bash
# Single source of truth for every version the labs use.
# Source this, do not copy values out of it.
#
#   . ./scripts/versions.sh
#   echo "$HARBOR_VERSION"
#
# Finding our own path has to work in zsh as well as bash, because zsh
# is the default shell on macOS and this file is meant to be sourced
# from an interactive one. zsh does not define BASH_SOURCE, and the
# unguarded form failed with "BASH_SOURCE[0]: parameter not set" - which
# under `set -u` in the caller takes the whole session with it.
#
# The eval hides zsh syntax from bash's expander, and vice versa.
if [ -n "${ZSH_VERSION:-}" ]; then
  eval '_versions_self="${(%):-%x}"'
else
  _versions_self="${BASH_SOURCE[0]:-$0}"
fi

ROOT="$(cd "$(dirname "$_versions_self")/.." && pwd)"
unset _versions_self
eval "$(grep -E '^[A-Z_]+=' "$ROOT/VERSIONS.md")"
export ROOT HARBOR_VERSION HARBOR_CHART_VERSION TRIVY_VERSION \
       COSIGN_VERSION KIND_VERSION MINIKUBE_VERSION HELM_VERSION \
       ESO_CHART_VERSION UBUNTU_SERIES VM_NAME VM_CPUS VM_MEMORY VM_DISK
