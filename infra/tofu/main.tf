# 1. Target Rechenzentrum Node: Oracle Cloud Always Free Ampere A1 ARM VPS
resource "oci_core_instance" "rechenzentrum_node" {
  availability_domain = var.oci_availability_domain
  compartment_id      = var.oci_compartment_id
  display_name        = "lfst-fachverfahren-rz-arm01"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  create_vnic_details {
    subnet_id        = var.oci_subnet_id
    assign_public_ip = true
    hostname_label   = "lfst-rz-arm01"
  }

  source_details {
    source_type             = "image"
    source_id               = var.oci_arm_image_id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  freeform_tags = {
    role        = "fachverfahren-rechenzentrum"
    environment = "production"
    managed_by  = "opentofu"
  }
}

# 2. Homelab Staging & Self-Hosted Runner Node: GMKtec NucBox G3 Plus (Proxmox VE)
resource "proxmox_virtual_environment_vm" "staging_runner_node" {
  name        = "lfst-staging-runner"
  description = "Staging & Self-Hosted GitHub Actions Runner for Fachverfahren Steuer"
  node_name   = var.proxmox_node_name
  vm_id       = 244

  clone {
    vm_id = var.proxmox_template_vm_id
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      username = "opsadmin"
      keys     = [var.ssh_public_key]
    }
  }

  tags = ["lfst-id244", "staging", "runner"]
}
