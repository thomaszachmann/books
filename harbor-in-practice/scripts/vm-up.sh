#!/usr/bin/env bash
# Bring up the Ubuntu VM that Harbor runs on. One command, same result
# on macOS, Windows and Linux - which is the whole reason this book uses
# Multipass rather than Vagrant or a hand-rolled VirtualBox image.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

if ! command -v multipass >/dev/null 2>&1; then
  echo "multipass not found. See Appendix A, or use any Ubuntu" >&2
  echo "$UBUNTU_SERIES host and skip to Chapter 3." >&2
  exit 1
fi

if multipass info "$VM_NAME" >/dev/null 2>&1; then
  echo "VM '$VM_NAME' already exists."
else
  echo "Launching '$VM_NAME' ($VM_CPUS cpu, $VM_MEMORY, $VM_DISK)"
  multipass launch "$UBUNTU_SERIES" \
    --name "$VM_NAME" \
    --cpus "$VM_CPUS" \
    --memory "$VM_MEMORY" \
    --disk "$VM_DISK" \
    --cloud-init "$ROOT/vm/cloud-init.yaml"
fi

IP=$(multipass info "$VM_NAME" --format json \
     | jq -r ".info.\"$VM_NAME\".ipv4[0]")

cat <<TXT

VM is up.

  name  $VM_NAME
  ip    $IP

Add this to your hosts file so that the certificate matches the name.
Docker refuses a certificate that does not match, and Chapter 3 shows
why fixing that with insecure-registries is the wrong answer.

  $IP  harbor.meridian.test

  macOS and Linux:  sudo vi /etc/hosts
  Windows:          C:\\Windows\\System32\\drivers\\etc\\hosts

Then:  multipass shell $VM_NAME
TXT
