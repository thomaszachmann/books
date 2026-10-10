terraform {
  required_version = ">= 1.8"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.116.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token # Lab: aus TF_VAR_pve_api_token
  insecure  = true              # Lab: selbstsigniertes PVE-Zertifikat
}
