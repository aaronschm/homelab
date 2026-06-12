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
    import_from  = proxmox_virtual_environment_download_file.talos.id
    interface    = "scsi0"
    size         = each.value.disk_gb
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = local.vlan_id["cluster"]
  }

  # Talos ignores cloud-init for app config but uses it for the static IP via
  # the nocloud datasource until the machine config takes over.
  initialization {
    datastore_id = var.vm_storage
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
    import_from  = proxmox_virtual_environment_download_file.talos.id
    interface    = "scsi0"
    size         = each.value.disk_gb
  }

  # Optional data disk (scsi1 -> /dev/sdb) for MinIO/local-path, carved from the
  # 'alpha' pool until the dedicated gamma drives are installed.
  dynamic "disk" {
    for_each = var.worker_data_disk_gb > 0 ? [1] : []
    content {
      datastore_id = var.worker_data_disk_storage
      interface    = "scsi1"
      size         = var.worker_data_disk_gb
    }
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = local.vlan_id["cluster"]
  }

  initialization {
    datastore_id = var.vm_storage
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
