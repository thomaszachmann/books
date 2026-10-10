output "inventory" {
  description = "Ansible-Inventory fuer code/infra-rke2"
  value = templatefile("${path.module}/inventory.tftpl", {
    servers = { for k, v in var.nodes : k => v.ip if v.role == "server" }
    agents  = { for k, v in var.nodes : k => v.ip if v.role == "agent" }
  })
}
