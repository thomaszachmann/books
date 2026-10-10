variable "pve_endpoint" {
  type    = string
  default = "https://pve.lab.internal:8006/"
}

variable "pve_api_token" {
  type      = string
  sensitive = true
}

variable "pve_node" {
  type    = string
  default = "pve"
}

variable "template_id" {
  type    = number
  default = 9000
}

variable "datastore" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "gateway" {
  type    = string
  default = "10.10.20.1"
}

variable "dns_server" {
  type    = string
  default = "10.10.20.1"
}

variable "ssh_public_key" {
  type = string
}

variable "nodes" {
  type = map(object({
    vm_id  = number
    ip     = string
    cores  = number
    memory = number
    disk   = number
    role   = string
  }))
  default = {
    "rke2-cp-1" = { vm_id = 211, ip = "10.10.20.11", cores = 2, memory = 4096,
    disk = 40, role = "server" }
    "rke2-cp-2" = { vm_id = 212, ip = "10.10.20.12", cores = 2, memory = 4096,
    disk = 40, role = "server" }
    "rke2-cp-3" = { vm_id = 213, ip = "10.10.20.13", cores = 2, memory = 4096,
    disk = 40, role = "server" }
    "rke2-wk-1" = { vm_id = 221, ip = "10.10.20.21", cores = 4, memory = 8192,
    disk = 60, role = "agent" }
    "rke2-wk-2" = { vm_id = 222, ip = "10.10.20.22", cores = 4, memory = 8192,
    disk = 60, role = "agent" }
    "rke2-wk-3" = { vm_id = 223, ip = "10.10.20.23", cores = 4, memory = 8192,
    disk = 60, role = "agent" }
  }
}
