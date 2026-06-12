# Pelican Wings gameserver VM(s) — Debian + Docker + Wings.
# Wings is the daemon that runs game-server containers; it is configured from
# the Pelican Panel (running in Kubernetes) by pasting the node's config into
# /etc/pelican/config.yml, after which the systemd unit starts it. cloud-init
# here installs Docker, the Wings binary and the (disabled) unit so the host is
# ready the moment you add the node in the Panel.

resource "proxmox_virtual_environment_file" "wings_cloudinit" {
  for_each = var.gameservers

  content_type = "snippets"
  datastore_id = var.image_storage
  node_name    = var.pve_node

  source_raw {
    file_name = "cloud-init-${each.key}.yml"
    data      = <<-EOT
      #cloud-config
      hostname: ${each.key}
      package_update: true
      packages:
        - qemu-guest-agent
        - ca-certificates
        - curl
        - tar
      write_files:
        - path: /etc/systemd/system/wings.service
          content: |
            [Unit]
            Description=Pelican Wings Daemon
            After=docker.service
            Requires=docker.service
            PartOf=docker.service

            [Service]
            WorkingDirectory=/etc/pelican
            ExecStart=/usr/local/bin/wings
            Restart=on-failure
            StartLimitInterval=180
            StartLimitBurst=30
            RestartSec=5s

            [Install]
            WantedBy=multi-user.target
      runcmd:
        - [systemctl, enable, --now, qemu-guest-agent]
        - install -m 0755 -d /etc/apt/keyrings
        - curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        - chmod a+r /etc/apt/keyrings/docker.asc
        - bash -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list'
        - apt-get update
        - apt-get install -y docker-ce docker-ce-cli containerd.io
        - systemctl enable --now docker
        - mkdir -p /etc/pelican /var/lib/pelican /var/log/pelican
        - curl -L -o /usr/local/bin/wings "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_amd64"
        - chmod +x /usr/local/bin/wings
        - systemctl daemon-reload
    EOT
  }
}

resource "proxmox_virtual_environment_vm" "gameserver" {
  for_each = var.gameservers

  name      = each.key
  vm_id     = each.value.vmid
  node_name = var.pve_node
  tags      = ["gameserver", "pelican", each.value.vlan_key]

  started = true
  on_boot = true

  # Start last, after the cluster is up.
  startup {
    order    = 6
    up_delay = 5
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
    import_from  = proxmox_virtual_environment_download_file.debian[0].id
    interface    = "scsi0"
    size         = each.value.disk_gb
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = local.vlan_id[each.value.vlan_key]
  }

  initialization {
    datastore_id      = var.vm_storage
    user_data_file_id = proxmox_virtual_environment_file.wings_cloudinit[each.key].id

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.vlans[each.value.vlan_key]
      }
    }

    user_account {
      keys     = var.ssh_public_keys
      username = "debian"
    }
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [disk[0].import_from]
  }
}
