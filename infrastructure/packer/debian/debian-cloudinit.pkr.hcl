packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Builds a reusable Debian 13 cloud-init VM *template* on Proxmox for utility
# VMs (e.g. the Gameserver / Pelican Wings host) and any non-Talos guest.
# Talos nodes do NOT use this — they boot the factory image (see ../../terraform/proxmox/images.tf).

variable "pve_url" {
  type    = string
  default = "https://10.10.20.2:8006/api2/json"
}

variable "pve_token_id" {
  type      = string
  sensitive = true
}

variable "pve_token_secret" {
  type      = string
  sensitive = true
}

variable "pve_node" {
  type    = string
  default = "pve"
}

variable "iso_file" {
  description = "Datastore volume id of the Debian netinst ISO."
  type        = string
  default     = "local:iso/debian-13.5.0-amd64-netinst.iso"
}

variable "template_vmid" {
  type    = number
  default = 9000
}

source "proxmox-iso" "debian" {
  proxmox_url              = var.pve_url
  username                 = var.pve_token_id
  token                    = var.pve_token_secret
  insecure_skip_tls_verify = true
  node                     = var.pve_node

  vm_id                = var.template_vmid
  vm_name              = "debian-13-cloudinit"
  template_description = "Debian 13 cloud-init template (built by Packer)"

  iso_file     = var.iso_file
  unmount_iso  = true
  qemu_agent   = true
  scsi_controller = "virtio-scsi-pci"

  cores  = 2
  memory = 2048

  disks {
    disk_size    = "20G"
    storage_pool = "local-lvm"
    type         = "scsi"
  }

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  # Drive the Debian installer via preseed served over Packer's HTTP server.
  http_directory = "http"
  boot_command = [
    "<esc><wait>auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"
  ]
  boot_wait = "5s"

  ssh_username = "debian"
  ssh_password = "build" # only used during build; image uses SSH keys via cloud-init
  ssh_timeout  = "20m"
}

build {
  sources = ["source.proxmox-iso.debian"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y qemu-guest-agent cloud-init",
      "sudo cloud-init clean",
    ]
  }
}
