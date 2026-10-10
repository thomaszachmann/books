output "nodes" {
  description = "Name -> IP aller VMs"
  value       = { for k, v in var.nodes : k => v.ip }
}

# Ansible-Inventory für Tag 8:
#   tofu output -raw ansible_inventory > ../infra-rke2/inventory.yaml
output "ansible_inventory" {
  value = yamlencode({
    all = {
      vars = { ansible_user = "ubuntu" }
      children = {
        rke2_servers = {
          hosts = {
            for k, v in var.nodes : k => { ansible_host = v.ip }
            if v.class == "server"
          }
        }
        rke2_agents = {
          hosts = {
            for k, v in var.nodes : k => { ansible_host = v.ip }
            if v.class != "server"
          }
        }
        gpu_nodes = {
          hosts = {
            for k, v in var.nodes : k => { ansible_host = v.ip }
            if v.class == "gpu"
          }
        }
      }
    }
  })
}
