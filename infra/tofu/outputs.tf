output "rechenzentrum_public_ip" {
  description = "Public IPv4 address of the OCI ARM Rechenzentrum node"
  value       = oci_core_instance.rechenzentrum_node.public_ip
}

output "staging_vm_id" {
  description = "Proxmox VM ID for staging and CI/CD runner"
  value       = proxmox_virtual_environment_vm.staging_runner_node.vm_id
}
