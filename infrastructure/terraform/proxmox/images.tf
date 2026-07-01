locals {
  vlan_tag = {
    mgmt    = 20
    dmz     = 24
    cluster = 25
  }

  # When the bridge is NOT VLAN-aware, emit null (untagged). Enable tagging only
  # after making vmbr0 VLAN-aware and trunking the VLANs on the UDM uplink.
  vlan_id = var.enable_vlan_tagging ? local.vlan_tag : {
    mgmt    = null
    dmz     = null
    cluster = null
  }
}

# State migration: renamed from the deprecated proxmox_virtual_environment_download_file.
# Remove these moved blocks after the next successful `terraform apply`.
moved {
  from = proxmox_virtual_environment_download_file.talos
  to   = proxmox_download_file.talos
}

moved {
  from = proxmox_virtual_environment_download_file.debian
  to   = proxmox_download_file.debian
}

# Talos nocloud image, downloaded onto the Proxmox node once and reused as the
# import source for every Talos VM disk.
resource "proxmox_download_file" "talos" {
  content_type            = "iso"
  datastore_id            = var.image_storage
  node_name               = var.pve_node
  url                     = var.talos_image_url
  file_name               = "talos-${var.talos_version}-nocloud-amd64.img"
  decompression_algorithm = "gz"
  overwrite               = false
}

# Debian genericcloud image, used as the import source for non-Talos utility VMs
# (e.g. the Pelican Wings gameserver). Imported directly via cloud-init.
resource "proxmox_download_file" "debian" {
  count        = length(var.gameservers) > 0 ? 1 : 0
  content_type = "iso"
  datastore_id = var.image_storage
  node_name    = var.pve_node
  url          = var.debian_image_url
  file_name    = "debian-13-genericcloud-amd64.img"
  overwrite    = false
}
