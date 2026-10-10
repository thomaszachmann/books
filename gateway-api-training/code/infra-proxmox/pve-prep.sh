#!/usr/bin/env bash
# Auf dem Proxmox-Host als root ausfuehren (PVE 9.x). Lab-Werte!
set -euo pipefail
STORAGE=${STORAGE:-local-lvm}
BRIDGE=${BRIDGE:-vmbr0}
IMG=noble-server-cloudimg-amd64.img

# 1) Rolle, User und API-Token fuer OpenTofu
pveum role add TofuProv -privs "VM.Allocate VM.Clone VM.Audit VM.PowerMgmt \
VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk \
VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options \
VM.GuestAgent.Audit Datastore.AllocateSpace Datastore.Audit \
SDN.Use SDN.Audit Sys.Audit"
pveum user add tofu@pve --comment "OpenTofu Lab"
pveum aclmod / -user tofu@pve -role TofuProv
pveum user token add tofu@pve provider --privsep 0

# 2) Ubuntu-24.04-Cloud-Image mit qemu-guest-agent
apt-get install -y libguestfs-tools
cd /var/lib/vz/template/iso
wget -nc "https://cloud-images.ubuntu.com/noble/current/$IMG"
virt-customize -a "$IMG" --install qemu-guest-agent \
  --truncate /etc/machine-id

# 3) Template VMID 9000
qm create 9000 --name ubuntu-2404-tpl --ostype l26 \
  --cores 2 --memory 2048 --cpu host \
  --net0 "virtio,bridge=$BRIDGE" --scsihw virtio-scsi-single \
  --agent enabled=1 --serial0 socket --vga serial0
qm set 9000 --scsi0 "$STORAGE:0,import-from=$PWD/$IMG,discard=on,ssd=1"
qm set 9000 --ide2 "$STORAGE:cloudinit" --boot order=scsi0
qm template 9000
