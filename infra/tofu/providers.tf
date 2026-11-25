terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

# Authentifizierung ueber terraform.tfvars (nie committen, siehe .gitignore):
#   PROXMOX_VE_ENDPOINT = https://192.168.178.26:8006/
#   PROXMOX_VE_API_TOKEN = "tofu@pve!automation=<secret>"
#   PROXMOX_VE_INSECURE = true (Homelab, selbstsigniertes Zertifikat)
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_tls_insecure

  ssh {
    agent    = false
    username = "root"
  }
}
