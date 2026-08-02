locals {
  # mgmt (VLAN 20) is the native PVID on the MikroTik trunk port — guests on VLAN 20
  # must always be UNTAGGED. The switch classifies untagged frames into VLAN 20 itself.
  # dmz (24) and cluster (25) are non-native and require explicit VLAN tags.
  vlan_id = {
    mgmt    = null  # native PVID — never tagged regardless of enable_vlan_tagging
    dmz     = var.enable_vlan_tagging ? 24 : null
    cluster = var.enable_vlan_tagging ? 25 : null
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
# content_type = "import" stores to local:import/ and enables the API-based
# disk import (import_from) which avoids SSH qm importdisk.
resource "proxmox_download_file" "talos" {
  content_type = "import"
  datastore_id = var.image_storage
  node_name    = var.pve_node
  url          = var.talos_image_url
  file_name    = "talos-${var.talos_version}-nocloud-amd64.raw"
  overwrite    = false
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
