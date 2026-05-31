# Homelab

K3s-based homelab cluster with VLAN isolation, GitOps via Argo CD, and fully scripted infrastructure provisioning.

## Architecture

| VLAN | Name | Subnet | Role |
|------|------|--------|------|
| 20 | Management | `10.10.20.0/24` | Admin LXC, Update Server, Load Balancer |
| 24 | DMZ | `10.10.24.0/24` | Traefik reverse proxy |
| 25 | Cluster | `10.10.25.0/24` | K3s nodes (no internet access) |

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

## Repository Structure

```
├── ansible/              # Ansible playbooks (WIP)
├── docs/                 # Setup guides for each component
├── kubernetes/
│   ├── platform/         # Cluster infrastructure (Longhorn, Argo CD)
│   ├── common/           # Shared resources (namespaces, sealed secrets)
│   └── apps/             # Application manifests
├── scripts/              # Bootstrap scripts for LXCs and VMs
└── cluster.conf          # IP addresses and K3s token
```

## Configuration

All IPs and the K3s token are defined in [`cluster.conf`](cluster.conf). Update it before running any scripts.
