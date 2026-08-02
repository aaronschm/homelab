locals {
  first_cp_ip = values(var.controlplane_nodes)[0]

  # With a single control plane the kube-vip VIP is unnecessary: point the
  # cluster endpoint straight at the control-plane IP. Set var.cluster_vip to a
  # non-empty value later only if you scale to 3 control planes.
  use_vip          = var.cluster_vip != ""
  endpoint_host    = local.use_vip ? var.cluster_vip : local.first_cp_ip
  cluster_endpoint = "https://${local.endpoint_host}:6443"

  time_patch = {
    machine = {
      time = {
        servers = [var.ntp_server != "" ? var.ntp_server : "10.10.20.2"]
      }
    }
  }

  # Registry mirror so the dark Cluster VLAN (no internet) can still pull
  # container images via the Registry LXC on the Management VLAN.
  registry_patch = var.registry_mirror_endpoint == "" ? {} : {
    machine = {
      registries = {
        mirrors = {
          "docker.io"       = { endpoints = [var.registry_mirror_endpoint] }
          "ghcr.io"         = { endpoints = [var.registry_mirror_endpoint] }
          "registry.k8s.io" = { endpoints = [var.registry_mirror_endpoint] }
          "gcr.io"          = { endpoints = [var.registry_mirror_endpoint] }
          "quay.io"         = { endpoints = [var.registry_mirror_endpoint] }
          "public.ecr.aws"  = { endpoints = [var.registry_mirror_endpoint] }
        }
      }
    }
  }

  vip_patch = local.use_vip ? {
    machine = {
      network = {
        interfaces = [{
          interface = "eth0"
          dhcp      = false
          vip       = { ip = var.cluster_vip }
        }]
      }
    }
  } : {}

  # Format + mount the worker data disks (scsi1=/dev/sdb, scsi2=/dev/sdc, ...).
  # Longhorn uses /var/mnt/longhorn (beta) and local-path/MinIO uses /var/mnt/alpha.
  # MinIO extra drives (raw passthrough, scsi3+) are appended to the same list.
  worker_disks_patch = (length(var.worker_data_disks) + length(var.minio_extra_disks)) == 0 ? {} : {
    machine = {
      disks = concat(
        [
          for i, d in var.worker_data_disks : {
            device     = "/dev/sd${substr("bcdefghijklmnopqrstuvwxyz", i, 1)}"
            partitions = [{ mountpoint = d.mountpoint }]
          }
        ],
        [
          for d in var.minio_extra_disks : {
            device     = d.device
            partitions = [{ mountpoint = d.mountpoint }]
          }
        ]
      )
    }
  }

  # Bind-mount every data-disk path into kubelet so hostPath volumes and
  # Longhorn can reach them under /var.
  kubelet_mounts_patch = (length(var.worker_data_disks) + length(var.minio_extra_disks)) == 0 ? {} : {
    machine = {
      kubelet = {
        extraMounts = concat(
          [
            for d in var.worker_data_disks : {
              destination = d.mountpoint
              type        = "bind"
              source      = d.mountpoint
              options     = ["bind", "rshared", "rw"]
            }
          ],
          [
            for d in var.minio_extra_disks : {
              destination = d.mountpoint
              type        = "bind"
              source      = d.mountpoint
              options     = ["bind", "rshared", "rw"]
            }
          ]
        )
      }
    }
  }
  # Cilium is installed as a Helm chart (see kubernetes/platform/cilium/).
  # Talos must be told NOT to install the default Flannel CNI so we get a clean
  # slate. This also disables kube-proxy (Cilium replaces it in eBPF mode).
  cilium_patch = {
    cluster = {
      network = {
        cni = { name = "none" }
      }
      proxy = { disabled = true }
    }
  }
}

# Generates and stores the cluster PKI / secrets in Terraform state.
# Treat state as a secret (encrypt the backend; never commit it).
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = compact([
    yamlencode({ machine = { install = { disk = var.install_disk } } }),
    yamlencode(local.time_patch),
    yamlencode(local.cilium_patch),
    local.use_vip ? yamlencode(local.vip_patch) : "",
    var.registry_mirror_endpoint != "" ? yamlencode(local.registry_patch) : "",
  ])
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = compact([
    yamlencode({ machine = { install = { disk = var.install_disk } } }),
    yamlencode(local.time_patch),
    yamlencode(local.cilium_patch),
    var.registry_mirror_endpoint != "" ? yamlencode(local.registry_patch) : "",
    (length(var.worker_data_disks) + length(var.minio_extra_disks)) > 0 ? yamlencode(local.worker_disks_patch) : "",
    (length(var.worker_data_disks) + length(var.minio_extra_disks)) > 0 ? yamlencode(local.kubelet_mounts_patch) : "",
  ])
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.controlplane_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value
}

# Bootstrap etcd on the first control plane (only once).
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_cp_ip
  endpoint             = local.first_cp_ip
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = values(var.controlplane_nodes)
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_cp_ip
  endpoint             = local.first_cp_ip
}
