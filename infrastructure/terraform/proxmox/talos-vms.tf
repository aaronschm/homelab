# Talos control-plane + worker VMs.
# Disks are imported from the downloaded Talos nocloud image. Talos machine
# configuration itself is applied by the sibling module (infrastructure/terraform/talos).

resource "proxmox_virtual_environment_vm" "controlplane" {
  for_each = var.controlplanes

  name      = each.key
  vm_id     = each.value.vmid
  node_name = var.pve_node
  tags      = ["talos", "controlplane", "k8s"]

  # Autostart: boot when the VM is created and on every PVE host boot.
  started = true
  on_boot = true

  # Start after the registry LXC (image mirror) but before workers.
  startup {
    order    = 2
    up_delay = 15
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = each.value.disk_gb
    file_format  = "raw"

    # import_from uses the Proxmox API import endpoint (no SSH required).
    # Requires the source storage (local) to have 'import' content type,
    # and proxmox_download_file to use content_type = "import".
    import_from = proxmox_download_file.talos.id
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.enable_vlan_tagging ? local.vlan_id["cluster"] : null
  }

  # Talos ignores cloud-init for app config but uses it for the static IP via
  # the nocloud datasource until the machine config takes over.
  initialization {
    datastore_id = var.vm_storage
    dns {
      servers = [var.vlans["cluster"]]
    }

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.vlans["cluster"]
      }
    }
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [disk[0].import_from]
  }
}

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = var.workers

  name      = each.key
  vm_id     = each.value.vmid
  node_name = var.pve_node
  tags      = ["talos", "worker", "k8s"]

  started = true
  on_boot = true

  # Start after the control plane.
  startup {
    order    = 3
    up_delay = 30
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = each.value.disk_gb
    file_format  = "raw"

    # import_from uses the Proxmox API import endpoint (no SSH required).
    import_from = proxmox_download_file.talos.id
  }

  # Optional data disks (scsi1, scsi2, ...) for Longhorn (beta) and MinIO (alpha).
  # Talos formats + mounts each at its mountpoint (see the talos module).
  dynamic "disk" {
    for_each = { for i, d in var.worker_data_disks : format("scsi%d", i + 1) => d }
    content {
      datastore_id = disk.value.storage
      interface    = disk.key
      size         = disk.value.size_gb
    }
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.enable_vlan_tagging ? local.vlan_id["cluster"] : null
  }

  initialization {
    datastore_id = var.vm_storage
    dns {
      servers = [var.vlans["cluster"]]
    }

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.vlans["cluster"]
      }
    }
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [disk[0].import_from]
  }
}
