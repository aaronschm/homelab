# Homelab

K3s-based homelab cluster with VLAN isolation, GitOps via Argo CD, and fully scripted infrastructure provisioning.

## Architecture

| VLAN | Name | Subnet | Role |
|------|------|--------|------|
| 20 | Management | `10.10.20.0/24` | Admin LXC, Update Server, Load Balancer |
| 24 | DMZ | `10.10.24.0/24` | Traefik reverse proxy and Gameserver |
| 25 | Cluster | `10.10.25.0/24` | K3s nodes (no internet access) |

## IP Assignments

| Host | Type | VLAN | IP |
|------|------|------|----|
| Admin LXC | LXC | 20 – Management | `10.10.20.20` |
| Load Balancer | LXC | 20 – Management | `10.10.20.21` |
| Update Server | LXC | 20 – Management | `10.10.20.100` |
| Registry Server | LXC | 20 – Management | `10.10.20.101` |
| DMZ Reverse Proxy (Traefik) | LXC | 24 – DMZ | `10.10.24.10` |
| Gameserver (Pelican Wing) | VM | 24 – DMZ | `10.10.24.20` |
| K3s Control Plane | VM | 25 – Cluster | `10.10.25.11` |
| K3s Agent | VM | 25 – Cluster | `10.10.25.101` |

> All IPs are also defined in [`cluster.conf`](cluster.conf). Update it before running any scripts.

## Setup Order

Follow this order — each step depends on the previous ones.

| # | Component | Doc | Script |
|---|-----------|-----|--------|
| 1 | Network / VLANs | [network-setup](docs/network-setup.md) | — |
| 2 | Admin LXC | [admin-setup](docs/admin-setup.md) | `scripts/admin-setup.sh` |
| 3 | Update Server | [update-server-setup](docs/update-server-setup.md) | `scripts/update-server-setup.sh` |
| 4 | DMZ Reverse Proxy | [dmz-reverse-proxy](docs/dmz-reverse-proxy.md) | `scripts/dmz-reverse-proxy-setup.sh` |
| 5 | Load Balancer | [load-balancer-setup](docs/load-balancer-setup.md) | `scripts/load-balancer-setup.sh` |
| 6 | Container Registry | [registry-setup](docs/registry-setup.md) | `scripts/registry-setup.sh` |
| 7 | K3s Cluster | [k3s-setup](docs/k3s-setup.md) | `scripts/k3s-control-plane-setup.sh`, `scripts/k3s-agent-setup.sh` |
| 8 | GitOps Bootstrap | [gitops-setup](docs/gitops-setup.md) | — |
| 9 | Gameserver (Wings) | [gameserver-setup](docs/gameserver-setup.md) | `scripts/gameserver-setup.sh` |

## Repository Structure

```
├── infrastructure/       # API-driven IaC (see docs/proxmox-iac.md)
│   ├── terraform/
│   │   ├── proxmox/      # bpg/proxmox: Talos VMs + LXC containers
│   │   └── talos/        # siderolabs/talos: cluster bootstrap + kubeconfig
│   └── packer/debian/    # cloud-init Debian template for utility VMs
├── ansible/              # UDM Pro firewall automation (UniFi API)
├── docs/                 # Setup guides for each component
├── kubernetes/
│   ├── bootstrap/        # Argo CD app-of-apps root
│   ├── platform/         # Cluster infrastructure (Longhorn, Argo CD)
│   ├── common/           # Shared resources (namespaces, sealed secrets)
│   └── apps/             # Application manifests
├── scripts/              # Legacy in-guest bootstrap scripts (being retired)
└── cluster.conf          # IP addresses (legacy/traditional method)
```

> **Provisioning is moving from manual scripts to declarative IaC.** The
> Proxmox API (Terraform `bpg/proxmox`) creates the VMs and LXCs, and Talos
> Linux bootstraps the Kubernetes cluster. See
> [`docs/proxmox-iac.md`](docs/proxmox-iac.md). The `scripts/` flow below is the
> legacy/traditional path, kept during the transition.

## Configuration

For the **legacy** scripted flow, IPs are defined in [`cluster.conf`](cluster.conf);
generate the K3s token at runtime (never commit it). For the **IaC** flow,
configuration lives in `infrastructure/terraform/*/terraform.tfvars` (git-ignored;
copy the `.example` files).
