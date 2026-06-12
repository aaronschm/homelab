###############################################################################
# Proxmox connection
###############################################################################

variable "pve_endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://pve.lan:8006/"
  type        = string
}

variable "pve_api_token" {
  description = "Proxmox API token: USER@REALM!TOKENID=UUID"
  type        = string
  sensitive   = true
}

variable "pve_insecure" {
  description = "Skip TLS verification (true for self-signed PVE certs)."
  type        = bool
  default     = true
}

variable "pve_ssh_username" {
  description = "SSH user on the Proxmox node (for snippet/image uploads)."
  type        = string
  default     = "root"
}

variable "pve_node" {
  description = "Name of the Proxmox node to deploy onto (e.g. pve)."
  type        = string
}

###############################################################################
# Storage / network
###############################################################################

variable "ct_storage" {
  description = "Datastore for LXC rootfs (e.g. local-lvm)."
  type        = string
  default     = "local-lvm"
}

variable "vm_storage" {
  description = "Datastore for VM disks (e.g. local-lvm)."
  type        = string
  default     = "local-lvm"
}

variable "image_storage" {
  description = "Datastore that holds ISOs/images and snippets (e.g. local)."
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Linux bridge for all guests (e.g. vmbr0)."
  type        = string
  default     = "vmbr0"
}

variable "enable_vlan_tagging" {
  description = <<-EOT
    Tag guest NICs with the VLAN ids in var.vlans. Requires vmbr0 to be
    VLAN-aware AND the UDM uplink port to trunk VLANs 20/24/25. Set false to
    deploy everything untagged on the bridge's native VLAN during transition.
  EOT
  type        = bool
  default     = true
}

# VLAN plan mirrors README.md / docs/network-setup.md
variable "vlans" {
  description = "VLAN id -> gateway map."
  type        = map(string)
  default = {
    mgmt    = "10.10.20.1" # VLAN 20
    dmz     = "10.10.24.1" # VLAN 24
    cluster = "10.10.25.1" # VLAN 25
  }
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into LXCs and cloud-init VMs."
  type        = list(string)
  default     = []
}

###############################################################################
# Talos VM image (from https://factory.talos.dev schematic)
###############################################################################

variable "talos_version" {
  description = "Talos Linux version, e.g. v1.13.4"
  type        = string
  # renovate: datasource=github-releases depName=siderolabs/talos
  default     = "v1.13.4"
}

variable "talos_image_url" {
  description = <<-EOT
    URL to the Talos nocloud raw image for your factory schematic, e.g.
    https://factory.talos.dev/image/<SCHEMATIC_ID>/<VERSION>/nocloud-amd64.raw.gz
    Build a schematic (add qemu-guest-agent) at https://factory.talos.dev.
  EOT
  type        = string
}

###############################################################################
# Cluster topology
###############################################################################

variable "controlplanes" {
  description = "Talos control-plane nodes. Key = name."
  type = map(object({
    vmid    = number
    ip      = string # CIDR, e.g. 10.10.25.11/24
    cores   = number
    memory  = number # MiB
    disk_gb = number
  }))
  default = {
    "25011" = { vmid = 25011, ip = "10.10.25.11/24", cores = 2, memory = 6144, disk_gb = 50 }
  }
}

variable "workers" {
  description = "Talos worker nodes. Key = name."
  type = map(object({
    vmid    = number
    ip      = string
    cores   = number
    memory  = number
    disk_gb = number
  }))
  # Worker co-locates MinIO (6x18TB, single-node multi-drive). MinIO + Longhorn
  # + workloads share this RAM. See docs/proxmox-iac.md for the sizing rationale:
  # ~24-32 GiB is comfortable for ~100 TiB of MinIO; 16 GiB is the practical
  # floor with reduced caching. Tune to your host's total RAM.
  default = {
    "25101" = { vmid = 25101, ip = "10.10.25.101/24", cores = 6, memory = 32768, disk_gb = 100 }
  }
}

# Extra data disks for the worker, attached as scsi1, scsi2, ... in list order.
# Longhorn (beta SSD) and MinIO (interim alpha pool) live here. Keep this list
# IDENTICAL to the one in the talos module: the talos module derives each disk's
# device from the same order (scsi1 -> /dev/sdb, scsi2 -> /dev/sdc, ...) and
# mounts it at .mountpoint. Set to [] to add no data disks.
variable "worker_data_disks" {
  description = "Ordered worker data disks. storage+size_gb used here; mountpoint used by the talos module."
  type = list(object({
    storage    = string
    size_gb    = number
    mountpoint = string
  }))
  default = []
}

# Physical disks (the 6x18TB) passed through to the worker for MinIO.
# bpg cannot create raw-device passthrough cleanly, so these are attached at the
# Proxmox level (see docs/proxmox-iac.md) and mounted by Talos via machine.disks.
# Listed here for documentation / future automation only.
variable "minio_disks_by_id" {
  description = "List of /dev/disk/by-id/* paths for the MinIO drives on the PVE host."
  type        = list(string)
  default     = []
}

variable "lxcs" {
  description = "LXC containers to provision. Key = hostname."
  type = map(object({
    vmid     = number
    ip       = string # CIDR
    vlan_key = string # key into var.vlans
    cores    = number
    memory   = number # MiB
    disk_gb  = number
  }))
  default = {
    "20101" = { vmid = 20101, ip = "10.10.20.101/24", vlan_key = "mgmt", cores = 1, memory = 2048, disk_gb = 50 }
    "24010" = { vmid = 24010, ip = "10.10.24.10/24", vlan_key = "dmz", cores = 1, memory = 1024, disk_gb = 8 }
  }
}

variable "lxc_template" {
  description = "LXC OS template volume id (e.g. local:vztmpl/debian-13-standard_*.tar.zst)."
  type        = string
}

variable "lxc_password" {
  description = "Initial root password for LXCs (use SSH keys; rotate after)."
  type        = string
  sensitive   = true
  default     = ""
}

###############################################################################
# Utility VMs (non-Talos) — e.g. the Pelican Wings gameserver host
###############################################################################

variable "debian_image_url" {
  description = "URL to the Debian 13 (trixie) genericcloud qcow2 image."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

# Gameserver VMs run Docker + Pelican Wings (the node daemon that launches game
# containers). The Pelican Panel (web UI) runs in Kubernetes; Wings stays on a
# dedicated VM so game I/O and Docker never compete with the cluster. Set to {}
# to provision none.
variable "gameservers" {
  description = "Non-Talos Debian VMs for Pelican Wings. Key = name (<vlan><ip>)."
  type = map(object({
    vmid     = number
    ip       = string # CIDR
    vlan_key = string # key into var.vlans
    cores    = number
    memory   = number # MiB
    disk_gb  = number
  }))
  default = {}
}
