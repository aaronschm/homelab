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
              ├── LXC 20099  AdGuard Home (DNS)          VLAN 20
              ├── LXC 20100  Forgejo git server           VLAN 20
              ├── LXC 20101  Registry / Zot mirror        VLAN 20
              ├── LXC 20102  Uptime Kuma                  VLAN 20
              ├── LXC 24010  Traefik DMZ reverse proxy    VLAN 24
              ├── VM  25011  Talos control plane          VLAN 25 (dark)
              └── VM  25101  Talos worker + MinIO         VLAN 25 (dark)
                              │  1×400 GB Longhorn SSD  (scsi1)
                              │  6×18 TB raw passthrough (scsi2-7)
                              └── Kubernetes cluster (v1.34 · Cilium · Argo CD)
                                   ├── platform/
                                   │    ├── Cilium CNI (kube-proxy replaced, WireGuard pod encryption)
                                   │    ├── Longhorn (default StorageClass, LUKS encrypted)
                                   │    ├── MinIO (6×18 TB, EC:2 ≈ 72 TB usable)
                                   │    ├── PostgreSQL (shared DB for all apps)
                                   │    ├── CSI-S3 driver (MinIO-backed PVCs)
                                   │    ├── local-path-provisioner (fast node-local PVCs)
                                   │    └── Grafana Alloy (log collection, IP anonymisation)
                                   └── apps/
                                        ├── network.isarcloud.eu  (WireGuard/VLAN/NAT dashboard)
                                        ├── legal.isarcloud.eu    (GDPR: Datenschutzerklärung, AVV, consent)
                                        ├── metrics.isarcloud.eu  (Grafana dashboards)
                                        ├── vault.isarcloud.eu    (Vaultwarden password manager)
                                        ├── auth.isarcloud.eu     (Authentik SSO/OIDC)
                                        ├── files.isarcloud.eu    (OwnCloud Infinite Scale)
                                        ├── photos.isarcloud.eu   (Immich photo library)
                                        ├── docs.isarcloud.eu     (Paperless-ngx)
                                        ├── media.isarcloud.eu    (Jellyfin)
                                        ├── requests.isarcloud.eu (Overseerr)
                                        ├── movies.isarcloud.eu   (Radarr)
                                        ├── tv.isarcloud.eu       (Sonarr)
                                        ├── torrent.isarcloud.eu  (qBittorrent)
                                        ├── matrix.isarcloud.eu   (Synapse, EU-only federation)
                                        ├── chat.isarcloud.eu     (Element web)
                                        ├── RustDesk relay        (remote desktop)
                                        ├── SimpleX SMP server    (zero-metadata chat relay)
                                        └── Pelican Panel         (game server management)
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
# Open the file with your editor, fill in mikrotik_password, then encrypt it:
SOPS_AGE_KEY_FILE=_local/age.key sops --encrypt --in-place ansible/group_vars/all.sops.yaml

# 2. Copy and fill in Terraform variable files
cp infrastructure/terraform/proxmox/terraform.tfvars.example infrastructure/terraform/proxmox/terraform.tfvars
cp infrastructure/terraform/talos/terraform.tfvars.example   infrastructure/terraform/talos/terraform.tfvars
# Edit both files with your real PVE API token, SSH key, drive paths, etc.

# 3. Full bring-up
# Use single quotes around passwords — double quotes break if the password contains ! or $
export MIKROTIK_AUTOMATION_PASSWORD='yourAutomationPassword'   # for the Ansible-managed service account
export MIKROTIK_DASHBOARD_PASSWORD='yourDashboardPassword'     # for network.isarcloud.eu login
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

## Services

| URL | Service | Status | Notes |
|-----|---------|--------|-------|
| `network.isarcloud.eu` | Network Dashboard | ✅ deployed | WireGuard, VLAN, NAT UI for CRS309 + CRS310 |
| `legal.isarcloud.eu` | Legal pages | ✅ deployed | GDPR: Datenschutzerklärung, AVV, consent, deletion |
| `metrics.isarcloud.eu` | Grafana | ✅ deployed | Cluster and app dashboards |
| `vault.isarcloud.eu` | Vaultwarden | 🟡 planned | Migrate from old LXC, signups disabled |
| `files.isarcloud.eu` | OwnCloud Infinite Scale | 🟡 planned | File sync via MinIO S3 backend |
| `photos.isarcloud.eu` | Immich | 🟡 planned | Photo library, face recognition opt-in (Art. 9 DSGVO) |
| `docs.isarcloud.eu` | Paperless-ngx | 🟡 planned | OCR document management |
| `media.isarcloud.eu` | Jellyfin | 🟡 planned | Media server, library on MinIO 18 TB |
| `requests.isarcloud.eu` | Overseerr | 🟡 planned | Movie/show request manager |
| `movies.isarcloud.eu` | Radarr | 🟡 planned | Movie collection manager |
| `tv.isarcloud.eu` | Sonarr | 🟡 planned | TV show collection manager |
| `torrent.isarcloud.eu` | qBittorrent | 🟡 planned | Download client |
| `matrix.isarcloud.eu` | Synapse | 🟡 planned | Matrix homeserver, EU-only federation |
| `chat.isarcloud.eu` | Element Web | 🟡 planned | Matrix client UI |
| *(no public URL)* | Authentik | 🟡 planned | SSO/OIDC for all services |
| *(no public URL)* | RustDesk | ✅ deployed | Self-hosted remote desktop relay |
| *(no public URL)* | SimpleX SMP | ✅ deployed | Zero-metadata chat relay |
| *(no public URL)* | Pelican Panel | ✅ deployed | Game server management |
| *(no public URL)* | PostgreSQL | ✅ deployed | Shared database (all apps) |
| *(no public URL)* | MinIO | ✅ deployed | S3 object store, 6×18 TB EC:2 |
| *(no public URL)* | Longhorn | ✅ deployed | Encrypted PVC storage |

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
