# --- Proxmox VE (GMKtec NucBox G3 Plus, pve-n150) ---
# Hinweis: Die frueher geplante Oracle-Cloud-ARM-Instanz (oci_*) ist
# dokumentiert, aber derzeit deaktiviert. Aktives Rechenzentrum: pve-n150.

variable "proxmox_api_url" {
  description = "Proxmox VE API endpoint on GMKtec NucBox G3 Plus (Intel N150)"
  type        = string
  default     = "https://192.168.178.26:8006/"
}

variable "proxmox_api_token" {
  description = "Proxmox API token (tofu@pve!automation). Via terraform.tfvars setzen, nie committen."
  type        = string
  sensitive   = true
}

variable "proxmox_node_name" {
  description = "Proxmox VE node name"
  type        = string
  default     = "pve-n150"
}

variable "proxmox_tls_insecure" {
  description = "Skip self-signed TLS check in homelab"
  type        = bool
  default     = true
}

variable "proxmox_template_vm_id" {
  description = "Cloud-Init Linux template VM ID on Proxmox (debian13-cloud)"
  type        = number
  default     = 9000
}
