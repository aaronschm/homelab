# Network Configuration

Having multiple VLANs allows segregation between servers and services, even on
the same physical hardware.

Network topology is documented visually in
[`Isarcloud Network Diagram.drawio`](Isarcloud%20Network%20Diagram.drawio) — open
it in [draw.io](https://app.diagrams.net/) or the draw.io VS Code extension.

## Hardware

| Device | Role | Management IP |
|--------|------|---------------|
| **MikroTik CRS309-1G-8S+** | L3 gateway, WireGuard, NAT, firewall, BGP-free routing | `10.10.1.2` |
| **MikroTik CRS310-1G-5S-4S+** | PoE managed switch, VLAN distribution | `10.10.1.3` |
| **Proxmox VE** (node `pve`) | Hypervisor — bridge `vmbr0`, VLAN-aware | `10.10.20.2` |
| **Access point** | Wi-Fi, punched into trusted VLAN 10 | — |

> Firewall rules are automated against both MikroTik devices via Ansible
> (`ansible/mikrotik.yml` + `ansible/vars/firewall-rules.yml`).
> A read-only `network-dashboard` user is created on both routers to feed the
> **[network.isarcloud.eu](https://network.isarcloud.eu)** management UI.

## Requirements

- **Layer 2/3 switch** with 802.1Q VLAN support and a trunk port to the Proxmox
  host carrying VLANs 10/20/24/25 (tagged).
- The Proxmox bridge `vmbr0` must be **VLAN-aware** (Datacenter → pve → Network →
  vmbr0 → Edit → tick "VLAN aware").
- Both MikroTik devices must be reachable from the Ansible host (VLAN 25 or 10)
  before running `task firewall`.

## VLANs

| VLAN | Name | Subnet | Description | Internet |
|------|------|--------|-------------|---------|
| **10** | Trusted | `10.10.10.0/24` | Workstations, IaC client, gaming rig | Yes |
| **20** | Server | `10.10.20.0/24` | Proxmox host, LXC services (DNS, Forgejo, Registry, Traefik) | Yes |
| **24** | DMZ | `10.10.24.0/24` | Traefik reverse-proxy LXC — edge TLS termination | Yes |
| **25** | Cluster | `10.10.25.0/24` | Talos Kubernetes nodes (dark VLAN — no internet) | **No** |

## IP Assignments

| Host | Proxmox ID | Type | VLAN | IP |
|------|-----------|------|------|----|
| Proxmox VE `pve` | — | hypervisor | 20 | `10.10.20.2` |
| AdGuard Home | `20099` | LXC | 20 | `10.10.20.99` |
| Forgejo | `20100` | LXC | 20 | `10.10.20.100` |
| Zot Registry (mirror) | `20101` | LXC | 20 | `10.10.20.101` |
| Uptime Kuma | `20102` | LXC | 20 | `10.10.20.102` |
| Traefik DMZ | `24010` | LXC | 24 | `10.10.24.10` |
| Talos control plane | `25011` | VM | 25 | `10.10.25.11` |
| Talos worker | `25101` | VM | 25 | `10.10.25.101` |
| Pelican Wings | `24020` | VM | 24 | `10.10.24.20` |
| Home Assistant | `20XXX` | VM | 20 | `10.10.20.X` (pool beta) |
| MikroTik CRS309 | — | switch | — | `10.10.1.2` |
| MikroTik CRS310 | — | switch | — | `10.10.1.3` |

> Guest IDs follow a `<vlan><host-octet>` scheme (e.g. `24010` = VLAN 24, `.10`).
> IPs are declared in `infrastructure/terraform/proxmox/terraform.tfvars`.

## Firewall Rules (MikroTik CRS309)

Rules are applied top-down with implicit deny-all at the end.
Applied via `task firewall` (`ansible/mikrotik.yml`).

### IaC / Management access (from VLAN 10)

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| VLAN 10 | `10.10.20.2` | TCP 8006 | Proxmox web UI + API |
| VLAN 10 | `10.10.25.11` | TCP 50000 | Talos API (config + bootstrap) |
| VLAN 10 | `10.10.25.11` | TCP 6443 | Kubernetes API |
| VLAN 10 | `10.10.20.99` | TCP 3000 | AdGuard admin UI |
| VLAN 10 | `10.10.25.0/24` | TCP 22 | Ansible SSH to cluster nodes (Talos Ansible extensions disabled — not used) |

### Cluster outbound (dark VLAN 25)

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| VLAN 25 | `10.10.20.101` | TCP 5000 | Container image pull-through (Zot mirror) |
| VLAN 25 | `10.10.20.2` | TCP 8006 | Talos bootstrap contacts Proxmox API |

### Ingress path (DMZ → Cluster)

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| `10.10.24.10` (Traefik) | VLAN 25 | TCP 80, 443 | Forward HTTP/HTTPS to in-cluster Services |
| Internet | `10.10.24.10` | TCP 443 | Traefik TLS ingress (ACME certs) |

### WAN rules

| VLAN | Internet | Reason |
|------|----------|--------|
| 10 – Trusted | Yes | Workstations, gaming, IaC tools |
| 20 – Server | Yes | Proxmox updates, Forgejo, registry upstream pulls |
| 24 – DMZ | Yes | Let's Encrypt ACME, reachability for users |
| 25 – Cluster | **No** | Dark VLAN — all image pulls go through Zot mirror |

## Internal Kubernetes ports (VLAN 25)

These ports must remain open within VLAN 25 for cluster operation:

| Port | Protocol | Service |
|------|----------|---------|
| 6443 | TCP | Kubernetes API server |
| 50000 | TCP | Talos apid |
| 2379–2380 | TCP | etcd |
| 10250 | TCP | kubelet API |
| 4240 | TCP | Cilium health check |
| 8472 | UDP | Cilium VXLAN (fallback) |
| 51871 | UDP | WireGuard (Cilium node-to-node encryption) |

## NetworkPolicies (in-cluster)

Kubernetes-level traffic control is enforced by Cilium eBPF (not MikroTik —
MikroTik only handles inter-VLAN routing). The policy files are in
`kubernetes/common/network-policies/`:

- **Default deny-all** — applied to every application namespace
- **allow-dns** — all pods may reach CoreDNS (port 53)
- **allow-from-traefik** — all pods may receive traffic from the Traefik ingress
- **App-specific egress** — per-app rules for PostgreSQL, Redis, MinIO, SMTP

Argo CD applies these via the `common` Argo app (see `kubernetes/bootstrap/apps/common.yaml`).

## DNS

AdGuard Home (LXC `20099`, `10.10.20.99`) serves as the DNS resolver for all VLANs.
AdGuard is pointed at the MikroTik as upstream and provides ad-blocking and
internal name resolution.

- `*.isarcloud.eu` — public DNS → `10.10.24.10` (Traefik DMZ), then forwarded
  in-cluster via Kubernetes Ingress
- Internal names resolve via AdGuard local DNS rewrites

## WireGuard VPN

WireGuard is terminated on the **MikroTik CRS309** (RouterOS WireGuard interface).
Peer management (key exchange, allowed IPs) is done via the
[network.isarcloud.eu](https://network.isarcloud.eu) dashboard.

**Key generation model (privacy-first):**
1. Browser generates an X25519 keypair using `@noble/curves` (client-side only)
2. Only the **public key** is sent to the backend
3. Backend registers the public key on the router and returns the server public
   key + endpoint
4. The private key **never leaves the browser**

## Vaultwarden migration (from LXC `vault.mozartcloud.app`)

Vaultwarden runs at **`vault.isarcloud.eu`** (Kubernetes pod). To migrate the
existing LXC data:

```bash
# 1. Stop the LXC (via Proxmox UI or `pct stop <id>`)
# 2. Copy SQLite database
kubectl cp /path/to/lxc/data/db.sqlite3 vaultwarden/<pod-name>:/data/db.sqlite3
# 3. Copy attachments
kubectl cp /path/to/lxc/data/attachments vaultwarden/<pod-name>:/data/attachments
# 4. Restart the pod
kubectl rollout restart deployment/vaultwarden -n vaultwarden
```

The URL change (`vault.mozartcloud.app` → `vault.isarcloud.eu`) requires users
to update their Bitwarden client server URL setting.

