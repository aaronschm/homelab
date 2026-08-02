locals {
  # Maps vlan_key → numeric VLAN tag for guest NICs.
  #
  # VLAN 20 (mgmt) is the PVID / native VLAN on the MikroTik trunk port,
  # so Proxmox guests on VLAN 20 must NOT have a VLAN tag — untagged frames are
  # automatically classified into VLAN 20 by the switch.  Setting vlan_id = null
  # leaves the NIC untagged, which is correct here.
  #
  # VLAN 24 (dmz) and VLAN 25 (cluster) are non-native VLANs and must be tagged.
  vlan_id = {
    mgmt    = null # native PVID — no tag
    dmz     = 24
    cluster = 25
  }
}
