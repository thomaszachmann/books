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

# Run a command on the lab VM. Multipass is the book's default; anyone
# on Colima+Rosetta (Appendix A) or an existing Ubuntu host sets
# HARBOR_VM_SSH=ubuntu@<ip> and the same scripts work over ssh.
vm_exec() {
  if [ -n "${HARBOR_VM_SSH:-}" ]; then
    ssh "$HARBOR_VM_SSH" "$@"
  elif command -v multipass >/dev/null 2>&1; then
    multipass exec "$VM_NAME" -- "$@"
  else
    echo "no way to reach the VM: install multipass or set HARBOR_VM_SSH=user@host" >&2
    return 1
  fi
}
vm_present() {
  if [ -n "${HARBOR_VM_SSH:-}" ]; then ssh -o ConnectTimeout=5 "$HARBOR_VM_SSH" true 2>/dev/null
  else multipass info "$VM_NAME" >/dev/null 2>&1; fi
}
