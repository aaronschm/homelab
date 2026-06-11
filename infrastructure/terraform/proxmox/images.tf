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

# Talos nocloud image, downloaded onto the Proxmox node once and reused as the
# import source for every Talos VM disk.
resource "proxmox_virtual_environment_download_file" "talos" {
  content_type            = "iso"
  datastore_id            = var.image_storage
  node_name               = var.pve_node
  url                     = var.talos_image_url
  file_name               = "talos-${var.talos_version}-nocloud-amd64.img"
  decompression_algorithm = "gz"
  overwrite               = false
}
