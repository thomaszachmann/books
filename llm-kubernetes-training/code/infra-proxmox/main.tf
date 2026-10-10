locals {
  ssh_key  = trimspace(file(pathexpand(var.ssh_public_key_file)))
  gpu_host = coalesce(var.gpu_pve_node, var.pve_node)
  host = {
    for k, v in var.nodes : k => v.class == "gpu" ? local.gpu_host : var.pve_node
  }
}

# Eine user-data-Datei pro VM (Hostname steckt darin)
resource "proxmox_virtual_environment_file" "user_data" {
  for_each     = var.nodes
  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = local.host[each.key]

  source_raw {
    file_name = "${each.key}-user.yaml"
    data = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
      hostname = each.key
      domain   = var.domain
      ssh_key  = local.ssh_key
    })
  }
}

resource "proxmox_virtual_environment_vm" "node" {
  for_each  = var.nodes
  name      = each.key
  vm_id     = each.value.vmid
  node_name = local.host[each.key]
  tags      = ["rke2", each.value.class]
  on_boot   = true

  clone {
    vm_id     = var.template_id
    node_name = var.pve_node # Template liegt hier
    full      = true
    retries   = 3
  }

  # GPU-VM: q35 + UEFI, damit die Karte als PCIe-Gerät erscheint
  machine = each.value.class == "gpu" ? "q35" : "pc"
  bios    = each.value.class == "gpu" ? "ovmf" : "seabios"

  dynamic "efi_disk" {
    for_each = each.value.class == "gpu" ? [1] : []
    content {
      datastore_id = var.vm_datastore
      type         = "4m"
    }
  }

  cpu {
    type  = "host"
    cores = var.sizes[each.value.class].cores
  }

  memory {
    dedicated = var.sizes[each.value.class].memory
    floating  = 0 # kein Ballooning (Pflicht bei Passthrough)
  }

  agent {
    enabled = true
  }

  scsi_hardware = "virtio-scsi-single" # Voraussetzung für iothread

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = var.sizes[each.value.class].disk
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  dynamic "hostpci" {
    for_each = each.value.class == "gpu" ? [var.gpu_mapping] : []
    content {
      device  = "hostpci0"
      mapping = hostpci.value
      pcie    = true
      rombar  = true
    }
  }

  initialization {
    datastore_id = var.vm_datastore
    dns {
      domain  = var.domain
      servers = var.dns_servers
    }
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id
  }
}
