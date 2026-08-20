#!/usr/bin/env bash
# Bring up the Ubuntu VM that Harbor runs on. One command, same result
# on macOS, Windows and Linux - which is the whole reason this book uses
# Multipass rather than Vagrant or a hand-rolled VirtualBox image.
#
# Except on Apple silicon, where it produces a machine Harbor cannot run
# in. ALLOW_ARM64=1 overrides the refusal below if you want to see it
# fail for yourself.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

# Harbor's released images are amd64 only - a single manifest, not an
# index. Multipass on Apple silicon makes an arm64 machine, so the
# containers cannot execute at all, and qemu user-mode emulation does
# not rescue it either: Valkey segfaults under it and core then retries
# Redis forever. Colima with Rosetta does work. See Appendix A.
if [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] \
   && [ -z "${ALLOW_ARM64:-}" ]; then
  cat >&2 <<'TXT'
Refusing: this is an Apple silicon Mac, and Multipass would build an
arm64 machine. Harbor's released images are amd64 only, so nothing in
it would start.

Use Colima with Rosetta instead:

  brew install colima docker docker-compose
  colima start --profile harbor --vm-type vz --vz-rosetta
  colima ssh --profile harbor -- sudo docker run --rm \
    --platform linux/amd64 alpine:3.20 uname -m

That last command must print x86_64. Then install Harbor inside that
machine, per Appendix A - Chapter 3 applies unchanged from there.

ALLOW_ARM64=1 to proceed anyway.
TXT
  exit 2
fi

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
