output "staging_ipv4" {
  description = "Static IPv4 of staging node (k3s)"
  value       = "192.168.178.27"
}

output "runner_ipv4" {
  description = "Static IPv4 of self-hosted GitHub Actions runner"
  value       = "192.168.178.28"
}

output "staging_vm_id" {
  description = "Proxmox VM ID for staging node"
  value       = proxmox_virtual_environment_vm.staging_node.vm_id
}

output "runner_vm_id" {
  description = "Proxmox VM ID for runner node"
  value       = proxmox_virtual_environment_vm.runner_node.vm_id
}
