# LXC containers (Proxmox CTs) — replaces manual creation of the
# Registry / DMZ Traefik / utility containers described in README.md.

variable "lxc_startup_order" {
  description = "Boot order per LXC hostname (lower starts first)."
  type        = map(number)
  default = {
    "20101" = 1 # registry (image mirror) must be up before Talos nodes pull images
    "24010" = 4 # traefik DMZ reverse proxy
  }
}

resource "proxmox_virtual_environment_container" "this" {
  for_each = var.lxcs

  node_name    = var.pve_node
  vm_id        = each.value.vmid
  unprivileged = true
  tags         = ["lxc", each.value.vlan_key]

  # Autostart on create and on every PVE host boot.
  started = true

  startup {
    order    = lookup(var.lxc_startup_order, each.key, 5)
    up_delay = 5
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.ct_storage
    size         = each.value.disk_gb
  }

  network_interface {
    name    = "eth0"
    bridge  = var.network_bridge
    vlan_id = local.vlan_id[each.value.vlan_key]
  }

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.vlans[each.value.vlan_key]
      }
    }

    user_account {
      keys     = var.ssh_public_keys
      password = var.lxc_password != "" ? var.lxc_password : null
    }
  }
}
