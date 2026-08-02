# Homelab

Declarative homelab on **Proxmox VE + Talos Kubernetes**, provisioned through the
Proxmox API and operated via GitOps (Argo CD). One command from your workstation
creates the LXCs and VMs, bootstraps the cluster, and hands operations to Argo CD.

See **[docs/proxmox-iac.md](docs/proxmox-iac.md)** for the full design, sizing,
and prerequisites. The network layout (with draw.io diagram) is in
**[docs/network-setup.md](docs/network-setup.md)**. The service catalogue lives in
**[docs/roadmap.md](docs/roadmap.md)**.

## Architecture

```
Internet ──► MikroTik CRS309 (gateway, WireGuard, NAT)
                │  trunk (VLANs 20/24/25)
             MikroTik CRS310 (PoE switch, VLAN distribution)
                │
             Proxmox VE — node "pve" (10.10.20.2)
              ├── LXC 20101  Registry / Zot mirror      VLAN 20
              ├── LXC 20100  Forgejo git server          VLAN 20
              ├── LXC 20099  AdGuard Home (DNS)          VLAN 20
              ├── LXC 24010  Traefik DMZ reverse proxy   VLAN 24
              ├── LXC 20102  Uptime Kuma                 VLAN 20
              ├── VM  25011  Talos control plane         VLAN 25 (dark)
              └── VM  25101  Talos worker + MinIO        VLAN 25 (dark)
                              │  6×18 TB hostPath drives
                              └── Kubernetes cluster
                                   ├── platform/  Cilium, Longhorn, MinIO, CSI-S3
                                   ├── apps/      OwnCloud, Immich, Jellyfin, …
                                   └── common/    NetworkPolicies, sealed-secrets
```

| VLAN | Name | Subnet | Role | Internet |
|------|------|--------|------|----------|
| 10 | Trusted | `10.10.10.0/24` | Workstations, IaC client | Yes |
| 20 | Server | `10.10.20.0/24` | Proxmox API, Registry, Forgejo, AdGuard | Yes |
| 24 | DMZ | `10.10.24.0/24` | Traefik reverse proxy | Yes |
| 25 | Cluster | `10.10.25.0/24` | Talos control plane + worker | No (dark) |

Guest names follow a **`<vlan><host-octet>`** scheme — e.g. `24010` = VLAN 24, host `.10`.

## Quick start

```bash
# 0. Install toolchain
task setup                                         # terraform, sops, age, talosctl via mise
ansible-galaxy collection install -r ansible/requirements.yml

# 1. Secrets bootstrap (once per machine)
task secrets:init                                  # generates _local/age.key
task vars:init                                     # creates ansible/group_vars/all.sops.yaml from template
# Edit ansible/group_vars/all.sops.yaml, then:
SOPS_AGE_KEY_FILE=_local/age.key sops --encrypt --in-place ansible/group_vars/all.sops.yaml

# 2. Copy and fill in Terraform variable files
cp infrastructure/terraform/proxmox/terraform.tfvars.example infrastructure/terraform/proxmox/terraform.tfvars
cp infrastructure/terraform/talos/terraform.tfvars.example   infrastructure/terraform/talos/terraform.tfvars
# Edit both files with your real PVE API token, SSH key, drive paths, etc.

# 3. Full bring-up
export MIKROTIK_AUTOMATION_PASSWORD="..."   # min 16 chars — for the Ansible-managed user
export MIKROTIK_DASHBOARD_PASSWORD="..."   # min 16 chars — for the network-dashboard UI user
task all    # firewall (MikroTik) → infra (Proxmox) → cluster (Talos) → gitops (Argo CD) → secrets
```

### Pre-flight checklist (before `task all`)

- [ ] `_local/age.key` exists (`task secrets:init`)
- [ ] `ansible/group_vars/all.sops.yaml` is encrypted with real `mikrotik_password` and S3 backup creds
- [ ] `infrastructure/terraform/proxmox/terraform.tfvars` — real PVE token, SSH key, LXC password
- [ ] `infrastructure/terraform/talos/terraform.tfvars` — `minio_extra_disks` paths set for 6×18 TB drives
- [ ] All `kubernetes/**/*-secret.sops.yaml` files contain real encrypted values (not `CHANGE_ME` placeholders)
- [ ] `MIKROTIK_AUTOMATION_PASSWORD` and `MIKROTIK_DASHBOARD_PASSWORD` exported in your shell
- [ ] MikroTik trunk port configured carrying VLANs 20/24/25 to Proxmox
- [ ] Proxmox `vmbr0` is VLAN-aware

### Secrets quick-reference

| Secret file | Key fields |
|---|---|
| `kubernetes/apps/router-dashboard/router-credentials-secret.sops.yaml` | `ROUTER_PASS`, `ROUTER_PASS_2` — use the `network-dashboard` password |
| `kubernetes/apps/owncloud/owncloud-secret.sops.yaml` | `OWNCLOUD_ADMIN_PASSWORD`, `OWNCLOUD_DB_PASSWORD`, `OWNCLOUD_OBJECTSTORE_KEY/SECRET` |
| `kubernetes/platform/minio/minio-secret.sops.yaml` | `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` |
| `kubernetes/apps/vaultwarden/vaultwarden-secret.sops.yaml` | `DATABASE_URL`, `ADMIN_TOKEN` |
| `kubernetes/apps/immich/immich-secret.sops.yaml` | `DB_PASSWORD` |
| `kubernetes/apps/synapse/synapse-secret.sops.yaml` | `SYNAPSE_POSTGRES_PASSWORD` |
| `ansible/group_vars/all.sops.yaml` | `mikrotik_password`, S3 backup creds |

To edit any secret: `task secrets:edit -- path/to/file.sops.yaml`

## Repository structure

```
├── infrastructure/
│   ├── terraform/proxmox/   # bpg/proxmox: Talos VMs + LXCs + gameserver VM
│   └── terraform/talos/     # siderolabs/talos: cluster bootstrap + kubeconfig
├── ansible/                 # MikroTik firewall, LXC provisioning, LXC backups
│   ├── inventory.ini        # all hosts (MikroTik, Proxmox, LXCs)
│   ├── group_vars/          # all.sops.yaml (SOPS-encrypted) or all.sops.example.yaml
│   ├── mikrotik.yml         # firewall rules, managed users (automation + network-dashboard)
│   ├── traefik.yml          # Traefik DMZ LXC
│   ├── registry-zot.yml     # Zot image mirror LXC
│   ├── forgejo.yml          # Forgejo git server LXC
│   ├── adguard.yml          # AdGuard Home DNS LXC
│   └── requirements.yml     # Ansible collections
├── kubernetes/
│   ├── bootstrap/           # Argo CD app-of-apps root
│   ├── platform/            # cluster infrastructure: Cilium, Longhorn, MinIO, Alloy, CSI-S3
│   ├── common/              # shared: NetworkPolicies (default-deny + allowlists)
│   └── apps/                # application manifests
│       ├── authentik/       # SSO / identity provider
│       ├── owncloud/        # file sync (S3 primary storage via MinIO)
│       ├── immich/          # photo library (S3 media storage via MinIO)
│       ├── jellyfin/        # media server (S3 media storage via MinIO)
│       ├── vaultwarden/     # password manager
│       ├── grafana/         # metrics dashboard
│       ├── synapse/         # Matrix chat (EU-only federation)
│       ├── router-dashboard/ # network.isarcloud.eu — WireGuard/NAT/VLAN UI
│       ├── legal/           # legal.isarcloud.eu — Datenschutzerklärung, AVV, consent
│       └── …
├── docs/
│   ├── proxmox-iac.md       # full design reference + migration notes
│   ├── network-setup.md     # VLAN layout, firewall rules, IP assignments
│   ├── roadmap.md           # service catalogue and status
│   └── Isarcloud Network Diagram.drawio  # visual network topology
└── Taskfile.yml             # one-touch bootstrap and secret management
```

## Key design decisions

| Decision | Choice | Reason |
|---|---|---|
| OS | Talos Linux | Immutable, API-managed, no SSH on nodes |
| CNI | Cilium | eBPF kube-proxy replacement + WireGuard pod encryption |
| Storage | Longhorn (PVCs) + MinIO (S3) | Encrypted at rest; MinIO on 6×18 TB drives (EC:2) |
| Secrets | SOPS + age | Encrypted secrets committed to git; no external KMS needed |
| GitOps | Argo CD app-of-apps | All Kubernetes state in git |
| Auth | Authentik | SSO/OIDC for all apps; forward-auth via Traefik middleware |
| Firewall | MikroTik CRS309 | RouterOS scripted via Ansible (`community.routeros`) |
| Ingress | Traefik (DMZ LXC) | Terminates TLS; forwards to cluster via VLAN 24→25 rule |
| Legal | `legal.isarcloud.eu` | GDPR/DSGVO: Datenschutzerklärung, AVV consent, deletion request |
| No HA | 1 CP + 1 worker | Hardware budget; acceptable downtime; users notified via ToS |
