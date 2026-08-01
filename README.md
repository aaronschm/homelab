# Homelab

Declarative homelab on **Proxmox VE + Talos Kubernetes**, provisioned through the
Proxmox API and operated via GitOps (Argo CD). One command from your workstation
creates the LXCs and VMs, bootstraps the cluster, and hands operations to Argo CD.

See **[docs/proxmox-iac.md](docs/proxmox-iac.md)** for the full design, sizing,
prerequisites, and migration notes. For an interactive overview, open
**[guide.html](guide.html)** in a browser. The target service catalogue lives in
**[docs/roadmap.md](docs/roadmap.md)**. The backup/rebuild playbook lives in the
**Recovery** tab of **[guide.html](guide.html)**.

## Architecture

| VLAN | Name | Subnet | Role | Internet |
|------|------|--------|------|----------|
| 10 | Trusted | `10.10.10.0/24` | Workstations, IaC client | Yes |
| 20 | Server | `10.10.20.0/24` | Registry LXC, Proxmox API | Yes |
| 24 | DMZ | `10.10.24.0/24` | Traefik reverse proxy | Yes |
| 25 | Cluster | `10.10.25.0/24` | Talos control plane + worker | No (dark) |

| Host | Name | Type | VLAN | IP |
|------|------|------|------|----|
| Registry (Zot mirror) | `20101` | LXC | 20 | `10.10.20.101` |
| DMZ Reverse Proxy (Traefik) | `24010` | LXC | 24 | `10.10.24.10` |
| Talos Control Plane | `25011` | VM | 25 | `10.10.25.11` |
| Talos Worker (+ MinIO) | `25101` | VM | 25 | `10.10.25.101` |

Topology: **1 control plane + 1 worker** (hardware-limited; not HA by choice).
Guest names follow a **`<vlan><ip>`** scheme (e.g. `24010` = VLAN 24, host `.10`;
`25101` = VLAN 25, host `.101`); the Proxmox `vmid` matches the name.
See [docs/network-setup.md](docs/network-setup.md) for VLANs and firewall rules.

## Quick start (from your workstation)

```bash
task setup      # installs terraform, sops, age, talosctl via mise
task all        # firewall (MikroTik) -> infra (Proxmox) -> cluster (Talos) -> gitops (Argo CD) -> secrets
```

Prerequisites and step-by-step are in [docs/proxmox-iac.md](docs/proxmox-iac.md).

## Repository structure

```
├── infrastructure/          # API-driven IaC
│   ├── terraform/proxmox/   # bpg/proxmox: Talos VMs, LXCs, gameserver VM
│   └── terraform/talos/     # siderolabs/talos: cluster bootstrap + kubeconfig
├── ansible/                 # MikroTik firewall + Zot registry mirror
├── kubernetes/
│   ├── bootstrap/           # Argo CD app-of-apps root
│   ├── platform/            # cluster infrastructure (Longhorn, MinIO, …)
│   ├── common/              # shared resources (sealed secrets)
│   └── apps/                # application manifests (PostgreSQL, Router Dashboard, Pelican, …)
├── docs/                    # design, network reference, roadmap
└── Taskfile.yml             # one-touch bootstrap and secret management
```

## Configuration & secrets

Per-environment config lives in `infrastructure/terraform/*/terraform.tfvars`
(copy the `.example` files). 

Kubernetes secrets are managed via **SOPS and age** and safely committed as `*.sops.yaml`. 
To edit a secret, use `task secrets:edit -- path/to/secret.sops.yaml`.
