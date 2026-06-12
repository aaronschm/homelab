# Homelab Service Roadmap

Where this homelab is going. This is the curated target catalogue of services —
point a new chat at this file to continue planning.

**Base platform (already in this repo):** Proxmox VE (node `pve`) · Talos Linux ·
**upstream Kubernetes** (not k3s) · Argo CD (GitOps) · Longhorn (storage) ·
MinIO (S3 + off-site backups) · PostgreSQL · Pelican (Panel in k8s + Wings VM).

## Legend

- **Status** — ✅ deployed · 🟡 planned · 🔭 future/maybe
- **Where** — `pod` (Kubernetes), `LXC`, or `VM` (Proxmox guest)
- Most apps run as **pods** under `kubernetes/apps/<name>/`; a few are better as
  their own guest (heavy I/O, kernel modules, or "appliance" software).

---

## 🔐 Authentication & Security

| Service | Status | Where | Notes |
|---|---|---|---|
| Authentik | 🟡 | pod | Identity provider / SSO; backs onto PostgreSQL. Put behind Traefik. |
| Vaultwarden | 🟡 | pod | Bitwarden-compatible password manager; small PVC on Longhorn. |
| AdGuard Home | 🟡 | pod | Network-wide DNS filtering; needs a stable ClusterIP/LoadBalancer + UDM DNS pointing at it. |
| WireGuard | 🟡 | LXC | VPN/remote access. Cleaner as an LXC (kernel module, host networking) than a pod. |
| CrowdSec | 🔭 | pod | IPS that parses logs to block malicious IPs; pairs with Traefik bouncer. |

## 📂 Storage & Data

| Service | Status | Where | Notes |
|---|---|---|---|
| MinIO | ✅ | pod | S3 object store; Longhorn backup target. Moves to the 6×18 TB gamma drives later. |
| PostgreSQL | ✅ | pod | Core DB for cluster services (Authentik, Pelican, Immich, Paperless, …). |
| ownCloud / Nextcloud | 🟡 | pod | File sync & share; large Longhorn PVC + PostgreSQL. |
| Immich | 🟡 | pod | Photo/video backup; PostgreSQL (pgvecto.rs) + big PVC; optional GPU later. |
| Paperless-ngx | 🟡 | pod | OCR document management; PostgreSQL + Longhorn PVC. |
| Stirling-PDF | 🔭 | pod | Stateless PDF tools; tiny. |
| Gameserver backup | ✅ | — | `mc mirror` of Wings data → MinIO (see `kubernetes/apps/pelican-panel/README.md`). |

## 🎬 Media & Entertainment

| Service | Status | Where | Notes |
|---|---|---|---|
| Jellyfin | 🟡 | pod | Media server; large media PVC; optional GPU passthrough for transcoding. |
| Jellyseerr | 🔭 | pod | Requests/discovery front-end for Jellyfin. |
| Arr stack (Prowlarr/Sonarr/Radarr) | 🔭 | pod | Automated media; shares the media PVC. |
| Navidrome | 🔭 | pod | Music streaming. |
| Audiobookshelf | 🔭 | pod | Audiobooks/podcasts with mobile apps. |
| Kavita | 🔭 | pod | Manga/comics/e-book reader. |
| MeTube | 🔭 | pod | yt-dlp web UI. |

## 🏠 Home Automation & Lifestyle

| Service | Status | Where | Notes |
|---|---|---|---|
| Home Assistant | 🟡 | VM | IoT core. A VM (or HAOS VM) is the most reliable; USB/Zigbee passthrough is easier than in a pod. |
| Mealie | 🔭 | pod | Recipe manager + meal planner; PostgreSQL. |
| Grocy | 🔭 | pod | Household ERP / pantry tracking. |
| Firefly III | 🔭 | pod | Personal finance; PostgreSQL. |
| LinkDing | 🔭 | pod | Bookmark manager. |

## 🛠️ DevOps & Infrastructure

| Service | Status | Where | Notes |
|---|---|---|---|
| Kubernetes (Talos) | ✅ | — | The cluster itself. **Upstream k8s**, not k3s. |
| Argo CD | ✅ | pod | GitOps continuous delivery; already the app-of-apps owner. |
| Forgejo | 🟡 | LXC | **Recommended** self-hosted Git: single Go binary, ~100 MB RAM, SQLite. Lightweight pick. |
| GitLab | 🔭 | VM | Heavy (~4 GB+ RAM). Only if you need the full CI/registry suite — otherwise use Forgejo. |
| Code-Server | 🔭 | pod | VS Code in the browser. |
| Custom DDNS | 🔭 | pod | Containerised IP updater (CronJob). |
| Pelican (Panel + Wings) | ✅ | pod + VM | Game-server management; Panel in k8s, Wings on VM `24020`. |
| CyberChef | 🔭 | pod | Stateless data-manipulation tool. |
| LanCache | 🔭 | LXC | Steam/GOG/Epic download cache for the gaming rig; large disk, host networking. |
| Pelican static site | 🔭 | pod | (the SSG; unrelated to Pelican game panel — keep the naming clash in mind). |

## 📊 Monitoring & Alerts

| Service | Status | Where | Notes |
|---|---|---|---|
| Homepage dashboard | 🟡 | pod | Service links + widgets. |
| Uptime Kuma | 🟡 | pod | Uptime monitoring + notifications. |
| Scrutiny | 🟡 | pod | S.M.A.R.T. monitoring; needs disk access (host paths / privileged) — runs on the worker. |
| VictoriaMetrics | 🔭 | pod | Time-series metrics DB. |
| Grafana | 🔭 | pod | Dashboards for metrics + logs. |
| Loki + Promtail | 🔭 | pod | Centralised logs; stores chunks in MinIO. |

## 💬 Communication & Remote Ops

| Service | Status | Where | Notes |
|---|---|---|---|
| Matrix Synapse | 🔭 | pod | Self-hosted chat + automation notifications; PostgreSQL. |
| RustDesk | 🔭 | LXC | Self-hosted remote desktop relay. |
| Private AI assistant | 🔭 | VM | LLM serving; needs GPU — future project on dedicated hardware. |

---

### Notes carried over from planning

- **No k3s.** The cluster is Talos + upstream Kubernetes from the start; anywhere
  the old list said "k3s", read "the existing Kubernetes cluster".
- **GitLab vs Forgejo:** start with Forgejo; only move to GitLab if you actually
  need its built-in CI and container registry.
- **GPU workloads** (Jellyfin transcoding, Immich ML, local LLM) need a GPU
  passed through to the worker VM or a dedicated VM — not available yet.
- **Anything stateful** uses a Longhorn PVC (backed up to MinIO → off-site) and,
  if it needs SQL, the in-cluster PostgreSQL.
