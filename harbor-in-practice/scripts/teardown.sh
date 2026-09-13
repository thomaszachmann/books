#!/usr/bin/env bash
# Remove what the labs created. Asks first.
#
#   teardown.sh          stop and remove Harbor, keep the VM; remove
#                        both clusters and any lab containers
#   teardown.sh --all    the same, and delete the VM itself
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"
ALL=; [ "${1:-}" = --all ] && ALL=1

cat <<TXT
This removes:

  Harbor inside the VM '$VM_NAME' (containers, /data, /opt/harbor)
  the kind cluster 'harbor-lab'
  the minikube profile 'harbor-lab'
  any lab containers still running
${ALL:+  the VM '$VM_NAME' itself (--all)}

TXT
read -r -p "Type 'yes' to continue: " reply
[ "$reply" = "yes" ] || { echo "Nothing done."; exit 0; }

if [ -n "$ALL" ] && command -v multipass >/dev/null 2>&1; then
  multipass delete "$VM_NAME" --purge 2>/dev/null \
    && echo "VM removed." || echo "No VM."
elif vm_present; then
  vm_exec bash -lc '
    cd /opt/harbor 2>/dev/null && sudo docker compose down -v || true
    sudo rm -rf /data/* /opt/harbor
  ' && echo "Harbor removed; the VM is still there."
else
  echo "No VM reachable; nothing to remove there."
fi

command -v kind >/dev/null 2>&1 \
  && kind delete cluster --name harbor-lab 2>/dev/null || true
command -v minikube >/dev/null 2>&1 \
  && minikube delete -p harbor-lab 2>/dev/null || true

for c in plain-registry harbor-lab-proxy; do
  docker rm -f "$c" >/dev/null 2>&1 && echo "Removed container $c" || true
done

echo "Done. Your hosts file entry is still there; remove it by hand."
