variable "oci_region" {
  description = "Oracle Cloud region for the target Rechenzentrum node"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "oci_compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "oci_subnet_id" {
  description = "OCI Subnet OCID for the ARM VPS"
  type        = string
}

variable "oci_availability_domain" {
  description = "OCI Availability Domain"
  type        = string
}

variable "oci_arm_image_id" {
  description = "ARM64 Enterprise Linux / Ubuntu LTS Image OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "Ed25519 SSH public key for Ansible provisioning"
  type        = string
}

variable "proxmox_api_url" {
  description = "Proxmox VE API endpoint on GMKtec NucBox G3 Plus (Intel N150)"
  type        = string
  default     = "https://192.168.178.10:8006/"
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
  description = "Cloud-Init Linux template VM ID on Proxmox"
  type        = number
  default     = 9000
}
