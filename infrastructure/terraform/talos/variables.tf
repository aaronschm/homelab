variable "cluster_name" {
  description = "Talos/Kubernetes cluster name."
  type        = string
  default     = "isarcloud"
}

variable "cluster_vip" {
  description = <<-EOT
    Shared control-plane VIP (kube-vip). Leave EMPTY for a single control plane
    (the endpoint then points directly at the control-plane IP). Only set this
    when you scale to 3 control planes for HA.
  EOT
  type        = string
  default     = ""
}

variable "registry_mirror_endpoint" {
  description = <<-EOT
    Registry pull-through mirror reachable from the dark Cluster VLAN, e.g.
    http://10.10.20.101:5000 (the Registry LXC). Leave EMPTY if the cluster
    nodes have direct internet access. Required when VLAN 25 has no internet.
  EOT
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version Talos should install."
  type        = string
  # renovate: datasource=github-releases depName=kubernetes/kubernetes
  default = "v1.34.1"
}

variable "talos_version" {
  description = "Talos machine config contract version, e.g. v1.13.4"
  type        = string
  # renovate: datasource=github-releases depName=siderolabs/talos
  default = "v1.13.4"
}

variable "install_disk" {
  description = "Disk Talos installs to inside the VM (matches scsi0)."
  type        = string
  default     = "/dev/sda"
}

# Keep IDENTICAL to the proxmox module's worker_data_disks. Each entry is
# formatted + mounted at .mountpoint; the device is derived from list order
# (scsi1 -> /dev/sdb, scsi2 -> /dev/sdc, ...). The mountpoints are also bind-
# mounted into the kubelet (required on Talos for hostPath/Longhorn access).
variable "worker_data_disks" {
  description = "Ordered worker data disks. mountpoint used here; storage/size_gb are documentation."
  type = list(object({
    storage    = string
    size_gb    = number
    mountpoint = string
  }))
  default = []
}

variable "controlplane_nodes" {
  description = "Map of control-plane node name -> IP (no CIDR)."
  type        = map(string)
  default = {
    "25011" = "10.10.25.11"
  }
}

variable "worker_nodes" {
  description = "Map of worker node name -> IP (no CIDR)."
  type        = map(string)
  default = {
    "25101" = "10.10.25.101"
  }
}
