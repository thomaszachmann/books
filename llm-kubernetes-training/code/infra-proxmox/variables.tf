variable "pve_node" {
  description = "Proxmox-Node mit Template und den CPU-VMs"
  type        = string
  default     = "pve1"
}

variable "gpu_pve_node" {
  description = "Proxmox-Node mit der GPU, null = pve_node"
  type        = string
  default     = null
}

variable "pve_insecure" {
  description = "Selbstsigniertes PVE-Zertifikat akzeptieren (nur Lab)"
  type        = bool
  default     = true
}

variable "template_id" {
  type    = number
  default = 9000
}

variable "vm_datastore" {
  type    = string
  default = "local-lvm"
}

variable "snippet_datastore" {
  type    = string
  default = "local"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN-Tag für das K8s-Netz, null = untagged"
  type        = number
  default     = null
}

variable "gateway" {
  type    = string
  default = "10.10.20.1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["10.10.20.1"]
}

variable "domain" {
  type    = string
  default = "lab.internal"
}

variable "ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "gpu_mapping" {
  description = "PCI-Resource-Mapping aus Tag 6"
  type        = string
  default     = "gpu0"
}

variable "nodes" {
  description = "Die sechs Cluster-VMs: VMID, IP, Klasse"
  type = map(object({
    vmid  = number
    ip    = string
    class = string # server | agent | gpu
  }))
  default = {
    "rke2-cp-1"  = { vmid = 211, ip = "10.10.20.11", class = "server" }
    "rke2-cp-2"  = { vmid = 212, ip = "10.10.20.12", class = "server" }
    "rke2-cp-3"  = { vmid = 213, ip = "10.10.20.13", class = "server" }
    "rke2-wk-1"  = { vmid = 221, ip = "10.10.20.21", class = "agent" }
    "rke2-wk-2"  = { vmid = 222, ip = "10.10.20.22", class = "agent" }
    "rke2-gpu-1" = { vmid = 231, ip = "10.10.20.31", class = "gpu" }
  }
}

variable "sizes" {
  description = "Ressourcen je Klasse (memory in MiB, disk in GiB)"
  type = map(object({
    cores  = number
    memory = number
    disk   = number
  }))
  default = {
    server = { cores = 4, memory = 8192, disk = 60 }
    agent  = { cores = 8, memory = 16384, disk = 100 }
    gpu    = { cores = 8, memory = 32768, disk = 200 }
  }
}
