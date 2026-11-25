# 1. Target Rechenzentrum Node: Oracle Cloud Always Free Ampere A1 ARM VPS
#    (dokumentiert, aber in dieser Umgebung bewusst NICHT verwaltet:
#     der GMKtec N150 Proxmox-Host ist jetzt das aktive Rechenzentrum.
#     Zum Aktivieren: provider "oci" konfigurieren und Count auf 1 setzen.)
# resource "oci_core_instance" "rechenzentrum_node" { ... }

# 2. Homelab Proxmox VE (GMKtec NucBox G3 Plus, pve-n150): Staging + Runner
#    Golden Image: VM 9000 (debian13-cloud, Cloud-Init-Template, per qm erstellt)

locals {
  # SSH-Keys direkt aus deinen Dateien (keine abgetippten Strings):
  # id_rsa = Arbeits-Key (dima-oci-k0s-cluster), id_ed25519 = persoenlicher Key,
  # oracle-wg = WireGuard-Admin-Key. Alle landen per Cloud-Init in beiden VMs.
  ssh_keys = [
    chomp(file(pathexpand("~/.ssh/id_rsa.pub"))),
    chomp(file("/home/dima/Documents/id_ed25519.pub")),
    chomp(file(pathexpand("~/.ssh/oracle-wg.pub"))),
    chomp(file(pathexpand("~/.ssh/iximiuz_labs_user.pub"))),
  ]
}

# Staging-Knoten: Fachverfahren-Vorabtest + k3s (statisch .27)
resource "proxmox_virtual_environment_vm" "staging_node" {
  name        = "lfst-staging"
  description = "Staging & Vorabtest Fachverfahren Steuer (k3s)"
  node_name   = var.proxmox_node_name
  vm_id       = 244
  started     = true

  clone {
    vm_id = var.proxmox_template_vm_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    size         = 32
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.178.27/24"
        gateway = "192.168.178.1"
      }
    }
    dns {
      servers = ["192.168.178.1"]
    }
    user_account {
      username = "opsadmin"
      keys     = local.ssh_keys
    }
  }

  tags = ["lfst-id244", "staging"]
}

# Runner-Knoten: Self-Hosted GitHub Actions Runner (statisch .28)
resource "proxmox_virtual_environment_vm" "runner_node" {
  name        = "lfst-runner"
  description = "Self-Hosted GitHub Actions Runner (lfst-fachverfahren-demo)"
  node_name   = var.proxmox_node_name
  vm_id       = 245
  started     = true

  clone {
    vm_id = var.proxmox_template_vm_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    size         = 32
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.178.28/24"
        gateway = "192.168.178.1"
      }
    }
    dns {
      servers = ["192.168.178.1"]
    }
    user_account {
      username = "opsadmin"
      keys     = local.ssh_keys
    }
  }

  tags = ["lfst-id244", "runner"]
}
