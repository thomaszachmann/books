#!/usr/bin/env bash
set -euo pipefail

PRIVS="Datastore.Allocate Datastore.AllocateSpace Datastore.Audit"
PRIVS+=" VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU"
PRIVS+=" VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType"
PRIVS+=" VM.Config.Memory VM.Config.Network VM.Config.Options"
PRIVS+=" VM.PowerMgmt VM.Migrate VM.Console VM.GuestAgent.Audit"
PRIVS+=" Sys.Audit Sys.Console SDN.Audit SDN.Use"
PRIVS+=" Mapping.Audit Mapping.Use"

pveum role add TofuProv -privs "${PRIVS// /,}"
pveum user add tofu@pve --comment "OpenTofu bpg/proxmox"
pveum aclmod / -user tofu@pve -role TofuProv
pveum user token add tofu@pve provider --privsep 0
