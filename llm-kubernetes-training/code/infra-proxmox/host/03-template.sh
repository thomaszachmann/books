#!/usr/bin/env bash
set -euo pipefail
VMID=9000
STORAGE=local-lvm
IMG=/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img
URL=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

[ -f "$IMG" ] || wget -q -O "$IMG" "$URL"
qm create "$VMID" --name ubuntu-2404-tpl --ostype l26 \
  --memory 2048 --cores 2 --cpu host --agent enabled=1 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single
qm set "$VMID" --scsi0 "$STORAGE:0,import-from=$IMG,discard=on,iothread=1"
qm set "$VMID" --ide2 "$STORAGE:cloudinit"
qm set "$VMID" --boot order=scsi0
qm set "$VMID" --serial0 socket --vga serial0
qm template "$VMID"
