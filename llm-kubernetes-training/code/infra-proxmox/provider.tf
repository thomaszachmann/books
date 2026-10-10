# Zugangsdaten nur aus der Umgebung:
#   PROXMOX_VE_ENDPOINT  = https://10.10.20.5:8006/
#   PROXMOX_VE_API_TOKEN = tofu@pve!provider=<secret>
provider "proxmox" {
  insecure = var.pve_insecure

  # Snippet-Upload (cloud-init user-data) geht nur per SSH
  ssh {
    agent    = true
    username = "tofu"
  }
}
