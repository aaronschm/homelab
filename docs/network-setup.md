# **Network Configuration** | Why multiple VLANs?

Having multiple VLANs allows segregation between servers and services, even on the same physical hardware.

I use:
- a **Management VLAN** (Proxmox API, registry mirror)
- a **DMZ (De-Militarized Zone)** for public-facing ingress
- a **Cluster VLAN** for the Talos Kubernetes nodes (dark — no internet)

The DMZ is isolated from the Cluster VLAN through firewall rules, ensuring that public-facing services cannot directly access internal cluster resources unless explicitly allowed.

> Firewall rules are automated against the UDM Pro — see [`ansible/udm-firewall.yml`](../ansible/udm-firewall.yml) and [`ansible/vars/firewall-rules.yml`](../ansible/vars/firewall-rules.yml). This document is the human-readable reference for that config.

## **Requirements**

- Managed **Layer 2 switch** with VLAN (802.1Q) support, plus a trunk port to the Proxmox host carrying VLANs 20/24/25.
- **Layer 3 router / firewall** for inter-VLAN routing — here a **UDM Pro** (UniFi Network 10.4.57, Zone-Based Firewall).
- The Proxmox bridge `vmbr0` must be **VLAN-aware** so per-VM/CT VLAN tags work.

## **Network Layout**

| VLAN | Name | Subnet | Description | Internet Access |
| :--- | :--- | :--- | :--- | :--- |
| **20** | **Management** | `10.10.20.0/24` | Proxmox host, Registry (Zot) mirror | **YES** |
| **24** | **DMZ** | `10.10.24.0/24` | Traefik reverse proxy (`10.10.24.10`) | **YES** |
| **25** | **Cluster** | `10.10.25.0/24` | Talos control plane + worker (dark VLAN) | **NO** |

> The workstation that runs the IaC sits on VLAN 10/20 and needs access to the Proxmox API (8006), the Talos API (50000), and the Kubernetes API (6443).

## **IP Assignments**

| Host | Type | VLAN | IP Address |
| :--- | :--- | :--- | :--- |
| Registry (Zot mirror) | LXC | 20 – Management | `10.10.20.101` |
| DMZ Reverse Proxy (Traefik) | LXC | 24 – DMZ | `10.10.24.10` |
| Talos Control Plane | VM | 25 – Cluster | `10.10.25.11` |
| Talos Worker (+ MinIO) | VM | 25 – Cluster | `10.10.25.101` |

> These IPs are defined declaratively in `infrastructure/terraform/proxmox/terraform.tfvars`.

## **Firewall Rules**

Rules are processed top-down with a final deny-all. They are applied via Ansible.

### Management / IaC access

| Source | Destination | Port/Protocol | Purpose |
| :--- | :--- | :--- | :--- |
| PC (VLAN 10) | VLAN 20 (Proxmox) | TCP 8006 | Proxmox API |
| PC (VLAN 10) | VLAN 25 nodes | TCP 50000 | Talos API (config + bootstrap) |
| PC (VLAN 10) | VLAN 25 control plane | TCP 6443 | Kubernetes API |

### Cluster outbound (dark VLAN)

| Source | Destination | Port/Protocol | Purpose |
| :--- | :--- | :--- | :--- |
| VLAN 25 (Cluster) | `10.10.20.101` | TCP 5000 | Container image pull-through (Zot) |

### Ingress path from DMZ to Cluster

| Source | Destination | Port/Protocol | Purpose |
| :--- | :--- | :--- | :--- |
| `10.10.24.10` (Traefik) | VLAN 25 | TCP 80, 443 | Forward web traffic to Kubernetes services |

## **WAN / Internet Rules**

| Source | Internet Access | Purpose |
| :--- | :--- | :--- |
| VLAN 20 | Enabled | Proxmox updates, Talos factory image, registry upstreams |
| VLAN 24 | Enabled | Traefik needs Let's Encrypt and external reachability |
| VLAN 25 | Disabled | Dark VLAN: no direct internet access (pulls via Zot mirror) |

## **Talos / Kubernetes internal traffic**

These ports must remain open within VLAN 25 for cluster operation:

- `6443`: Kubernetes API server
- `50000`: Talos apid (machine config / bootstrap)
- `2379-2380`: etcd client and peer communication
- `10250`: kubelet API

## **Implementation Notes**

- Create the VLANs on the UDM Pro first and trunk them to the Proxmox host.
- Make `vmbr0` VLAN-aware before applying Terraform with `enable_vlan_tagging = true`.
- Verify that a node in VLAN 25 cannot reach the internet directly.
- Verify that VLAN 25 can reach `10.10.20.101:5000` (the Zot mirror).
