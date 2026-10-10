resource "proxmox_virtual_environment_vm" "node" {
  for_each = var.nodes

  name      = each.key
  node_name = var.pve_node
  vm_id     = each.value.vm_id
  tags      = ["rke2", each.value.role]
  on_boot   = true

  clone {
    vm_id = var.template_id
    full  = true
  }

  agent {
    enabled = true # qemu-guest-agent ist im Template (pve-prep.sh)
  }

  cpu {
    cores = each.value.cores
    type  = "host" # Cilium/eBPF profitiert von allen CPU-Flags
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = each.value.disk
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.datastore
    dns {
      domain  = "lab.internal"
      servers = [var.dns_server]
    }
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }
    user_account {
      username = "ubuntu"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }
}
