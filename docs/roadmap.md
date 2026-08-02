# Homelab Service Roadmap

Where this homelab is going. This is the curated target catalogue of services —
point a new chat at this file to continue planning.

**Base platform (already in this repo):** Proxmox VE (node `pve`) · Talos Linux ·
**upstream Kubernetes** · Argo CD (GitOps) · Cilium (CNI + eBPF NetworkPolicies) ·
Longhorn (PVC storage) · MinIO S3 (6×18 TB, EC:2) · PostgreSQL · SOPS/age secrets ·
Legal pages (Datenschutzerklärung + AVV + face-consent) at `legal.isarcloud.eu` ·
Grafana Alloy (privacy-preserving log pipeline).

## Legend

- **Status** — ✅ deployed / in-repo · 🟡 planned / partially done · 🔭 future/maybe
- **Where** — `pod` (Kubernetes), `LXC`, or `VM` (Proxmox guest)

---

## 🔐 Authentication & Security

| Service | Status | Where | Notes |
|---|---|---|---|
| Authentik | 🟡 | pod | SSO/OIDC; forward-auth middleware on Traefik. Manifest in `kubernetes/apps/authentik/`. |
| Vaultwarden | 🟡 | pod | `vault.isarcloud.eu`; migrate SQLite + attachments from old LXC. `SIGNUPS_ALLOWED: "false"`. |
| AdGuard Home | ✅ | LXC `20099` | DNS resolver + ad-blocking. Managed by `ansible/adguard.yml`. |
| Cilium | ✅ | pod | CNI; kube-proxy replacement; WireGuard node-to-node encryption; Hubble UI. |
| NetworkPolicies | ✅ | — | Default-deny + allow rules for 11 namespaces via `kubernetes/common/network-policies/`. |
| Legal / GDPR | ✅ | pod | `legal.isarcloud.eu` — Datenschutzerklärung, AVV/ToS, face-consent, deletion form. |
| CrowdSec | 🔭 | pod | IPS; pairs with Traefik bouncer plugin. |

## 📂 Storage & Data

| Service | Status | Where | Notes |
|---|---|---|---|
| MinIO | ✅ | pod | 6×18 TB hostPath, EC:2 (~72 TB usable). S3 endpoint for all apps. |
| Longhorn | ✅ | pod | Default PVC class on beta SSD. 6-hourly backups to MinIO. |
| PostgreSQL | ✅ | pod | Shared DB for Authentik, Immich, OwnCloud, Paperless, etc. |
| OwnCloud Infinite Scale | 🟡 | pod | `files.isarcloud.eu`. Primary storage via MinIO S3 objectstore. |
| Immich | 🟡 | pod | `photos.isarcloud.eu`. Media on MinIO S3 (18 TB drives); model-cache on `local-path`. |
| Paperless-ngx | 🟡 | pod | `docs.isarcloud.eu`. OCR document management; PostgreSQL + Longhorn PVC. |
| Stirling-PDF | 🔭 | pod | Stateless PDF tools. |
| Gameserver backup | ✅ | — | `mc mirror` Wings data → MinIO. |

## 🎬 Media & Entertainment

| Service | Status | Where | Notes |
|---|---|---|---|
| Jellyfin | 🟡 | pod | `media.isarcloud.eu`. Media on MinIO S3 (18 TB drives); config on `local-path`. |
| Jellyseerr | 🔭 | pod | Requests front-end for Jellyfin. |
| Arr stack | ✅ | pod | Overseerr (`requests`) + Radarr (`movies`) + Sonarr (`tv`) + qBittorrent (`torrent`). Manifests in `kubernetes/apps/media/`. |
| Navidrome | 🔭 | pod | Music streaming. |
| Audiobookshelf | 🔭 | pod | Audiobooks + podcasts. |
| Kavita | 🔭 | pod | Manga/comics/e-books. |
| MeTube | 🔭 | pod | yt-dlp web UI. |

## 🏠 Home Automation & Lifestyle

| Service | Status | Where | Notes |
|---|---|---|---|
| Home Assistant | 🟡 | VM | IoT core on pool beta. Use `qm move-disk <VMID> scsi0 beta` to move from alpha. |
| Mealie | 🔭 | pod | Recipe manager + meal planner. |
| Grocy | 🔭 | pod | Household ERP / pantry. |
| Firefly III | 🔭 | pod | Personal finance. |
| LinkDing | 🔭 | pod | Bookmark manager. |

## 🛠️ DevOps & Infrastructure

| Service | Status | Where | Notes |
|---|---|---|---|
| Kubernetes (Talos) | ✅ | — | Single CP + worker. Not HA by choice (hardware budget). |
| Argo CD | ✅ | pod | GitOps app-of-apps. Excludes `*.sops.yaml` from reconciliation. |
| Forgejo | ✅ | LXC `20100` | Self-hosted git. CI runner → inject SSH key as Forgejo secret. |
| Zot Registry | ✅ | LXC `20101` | Pull-through mirror for dark VLAN 25. |
| Network Dashboard | ✅ | pod | `network.isarcloud.eu`. WireGuard, NAT, VLAN UI. Client-side WG key gen. Dual-router (CRS309 + CRS310). |
| Grafana Alloy | ✅ | pod | Log collection; IP anonymisation (SHA-256 hash); Prometheus metrics forwarded unmodified. |
| Pelican (Panel + Wings) | ✅ | pod + VM | Game-server management. |
| Custom DDNS | 🔭 | pod | CronJob IP updater. |
| Code-Server | 🔭 | pod | VS Code in browser. |
| CyberChef | 🔭 | pod | Stateless data tools. |
| LanCache | 🔭 | LXC | Steam/GOG/Epic download cache. |
| Image update scanning | 🔭 | — | Service to detect image updates and prompt approval before Renovate merges. |
| Testing environment | 🔭 | — | Separate Talos cluster or namespace for staging. |

## 📊 Monitoring & Alerts

| Service | Status | Where | Notes |
|---|---|---|---|
| Uptime Kuma | ✅ | LXC `20102` | Uptime monitoring + notifications. |
| Scrutiny | 🟡 | pod | S.M.A.R.T. monitoring; worker-node hostPath + privileged access. |
| VictoriaMetrics | 🔭 | pod | Long-term metrics storage. |
| Grafana | ✅ | pod | `metrics.isarcloud.eu`. Dashboards; receives anonymised metrics from Alloy. |
| Loki | 🔭 | pod | Log aggregation; chunks stored in MinIO. |
| Homepage | 🔭 | pod | Service overview dashboard. |

## 💬 Communication & Remote Ops

| Service | Status | Where | Notes |
|---|---|---|---|
| Matrix Synapse | 🟡 | pod | `chat.isarcloud.eu`. Federation restricted to EU IP ranges only (Traefik IPAllowList). |
| SimplexChat server | ✅ | pod | Manifest in `kubernetes/apps/simplex/`. Zero-metadata relay — messages never stored. |
| RustDesk | ✅ | pod | Self-hosted remote desktop relay + signalling. Manifest in `kubernetes/apps/rustdesk/`. |
| Private AI assistant | 🔭 | VM | GPU-gated; future hardware. |

---

## GDPR / DSGVO compliance checklist

| Item | Status | Where |
|---|---|---|
| Datenschutzerklärung (privacy notice) | ✅ | `legal.isarcloud.eu/datenschutz.html` |
| AVV / Auftragsverarbeitungsvertrag acceptance | ✅ | `legal.isarcloud.eu/avv.html` — presented during onboarding |
| Face recognition opt-in consent (Art. 9 DSGVO) | ✅ | `legal.isarcloud.eu/consent-face.html` |
| Data deletion request | ✅ | `legal.isarcloud.eu/deletion-request.html` |
| Log anonymisation (IP hashing, User-Agent dropped) | ✅ | Grafana Alloy pipeline |
| `SIGNUPS_ALLOWED: "false"` on Vaultwarden | 🟡 | `kubernetes/apps/vaultwarden/vaultwarden.yaml` |
| Immich face recognition OFF by default | ✅ | Default in Immich; explicit consent required |
| Matrix federation restricted to EU | ✅ | `kubernetes/apps/synapse/federation-eu-only.yaml` |
| Off-site backup AVV with storage friend | 🟡 | Manual — create AVV before enabling `lxc-backup.yml` |

---

## Notes

- **No k8s HA** — 1 CP + 1 worker. Downtime accepted. Users acknowledge in ToS.
  etcd snapshotted; Longhorn→MinIO→off-site backup chain protects volume data.
- **Cilium is permanent** — kube-proxy disabled at the Talos level; Cilium is
  the only CNI. eBPF NetworkPolicies are enforced in-cluster; MikroTik handles
  inter-VLAN routing.
- **MinIO EC:2** — 6 drives, 4 data + 2 parity ≈ 72 TB usable. Tolerates up to
  2 simultaneous drive failures. All data additionally backed up off-site.
- **GPU workloads** (Jellyfin transcoding, Immich ML, LLM) need a GPU passed
  through to the worker VM — not available yet.
- **Image scanning** — `latest` tags acceptable short-term; a dedicated approval
  service will be added before production user onboarding.
