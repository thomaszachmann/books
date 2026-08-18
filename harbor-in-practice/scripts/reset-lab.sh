#!/usr/bin/env bash
# The middle level of reset: keep the machine and the certificates,
# destroy what Harbor has accumulated.
#
#   restart      multipass stop / start   keeps everything
#   reset        this script              keeps the VM and the certs
#   teardown     scripts/teardown.sh      keeps nothing
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

if ! multipass info "$VM_NAME" >/dev/null 2>&1; then
  echo "No VM '$VM_NAME'. Run 'make vm-up' first."
  exit 1
fi

cat <<TXT
This removes, inside the VM '$VM_NAME':

  every running Harbor container
  /data          all images, all database contents, all scan results
  /opt/harbor    the rendered configuration

It keeps the machine, Docker, and your certificates.

TXT
read -r -p "Type 'yes' to continue: " reply
[ "$reply" = "yes" ] || { echo "Nothing done."; exit 0; }

multipass exec "$VM_NAME" -- bash -lc '
  cd /opt/harbor 2>/dev/null && sudo docker compose down -v || true
  sudo rm -rf /data/* /opt/harbor
  sudo mkdir -p /data
'
echo "Reset. Chapter 3 starts from here."
