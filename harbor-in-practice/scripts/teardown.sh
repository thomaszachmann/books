#!/usr/bin/env bash
# Remove everything the labs created. Asks first, because it deletes
# the VM and both clusters.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

cat <<TXT
This removes:

  the Multipass VM '$VM_NAME' and everything in it
  the kind cluster 'harbor-lab'
  the minikube profile 'harbor-lab'
  any lab containers still running

TXT
read -r -p "Type 'yes' to continue: " reply
[ "$reply" = "yes" ] || { echo "Nothing done."; exit 0; }

if command -v multipass >/dev/null 2>&1; then
  multipass delete "$VM_NAME" --purge 2>/dev/null \
    && echo "VM removed." || echo "No VM."
fi

command -v kind >/dev/null 2>&1 \
  && kind delete cluster --name harbor-lab 2>/dev/null || true
command -v minikube >/dev/null 2>&1 \
  && minikube delete -p harbor-lab 2>/dev/null || true

for c in plain-registry harbor-lab-proxy; do
  docker rm -f "$c" >/dev/null 2>&1 && echo "Removed container $c" || true
done

echo "Done. Your hosts file entry is still there; remove it by hand."
