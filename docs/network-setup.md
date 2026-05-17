# **Network Configuration** | Why multiple VLANs?

Having multiple VLANs allows segregation between servers and services, even on the same physical hardware.

I use:
- a **Management VLAN**
- a **DMZ (De-Militarized Zone)**
- a **Cluster VLAN** for Kubernetes nodes and internal traffic

The DMZ is isolated from the Cluster VLAN through firewall rules, ensuring that public-facing services cannot directly access internal cluster resources unless explicitly allowed.

## **Requirements**

One or more of the following components are required inside the network:

- Managed **Layer 2 Switch** with VLAN (802.1Q) support
- **Layer 3 Router / Firewall** capable of inter-VLAN routing
- Self-hosted firewall appliance using pfSense or OPNsense

## **Network Layout**

| VLAN | Name | Subnet | Description | Internet Access |
| :--- | :--- | :--- | :--- | :--- |
| **20** | **Management** | `10.10.20.0/24` | Admin LXC, Update Server, Load Balancer | **YES** |
| **24** | **DMZ** | `10.10.24.0/24` | Traefik Reverse Proxy (`10.10.24.10`) | **YES** |
| **25** | **Cluster** | `10.10.25.0/24` | K3s Control Planes & Agents (Dark VLAN) | **NO** |

## **Firewall Rules**

These rules define the allowed traffic between VLANs and external networks. Rules should be processed top-down, with a final deny-all policy at the end.

### Management Access

| Source | Destination | Port/Protocol | Purpose |
| :--- | :--- | :--- | :--- |
| VLAN 20 (Admin LXC) | VLAN 24, VLAN 25 | TCP 2022 | SSH management access |
| VLAN 20 (Admin LXC) | VLAN 20 (Load Balancer) | TCP 6443 | Kubernetes API access |

### Cluster Outbound

| Source | Destination | Port/Protocol | Purpose |
| :--- | :--- | :--- | :--- |
| VLAN 25 (Cluster) | `10.10.20.100` | TCP 3142 | Apt-cacher update proxy |
| VLAN 25 (Cluster) | `10.10.20.100` | TCP 80 | Script and binary fetching from Update Server |
| VLAN 25 (Cluster) | `10.10.20.21` | TCP 6443 | Agents reaching K3s API via Load Balancer |

### Ingress Path from DMZ to Cluster

| Source | Destination | Port/Protocol | Purpose |
| :--- | :--- | :--- | :--- |
| `10.10.24.10` (Traefik) | VLAN 25 | TCP 80, 443 | Forward web traffic to Kubernetes services |
| `10.10.24.10` (Traefik) | VLAN 25 | TCP 10250 | Kubelet metrics and dashboard access |

## **WAN / Internet Rules**

| Source | Internet Access | Purpose |
| :--- | :--- | :--- |
| VLAN 20 | Enabled | Admin tooling and update access |
| VLAN 24 | Enabled | Traefik needs LetsEncrypt and external reachability |
| VLAN 25 | Disabled | Dark VLAN: no direct internet access |

## **K3s Internal Traffic**

These ports must remain open within VLAN 25 for cluster operation. They typically stay inside the subnet and do not require router-level forwarding.

- `6443`: K3s API server
- `2379-2380`: Etcd client and peer communication
- `8472` (UDP): Flannel VXLAN / pod networking
- `10250`: Kubelet API

## **Implementation Notes**

- Create VLANs on the router/firewall first.
- Assign static IPs for the Update Server, Load Balancer, and Traefik.
- Verify that a node in VLAN 25 cannot reach the internet directly.
- Verify that VLAN 25 can reach `10.10.20.100:3142` for package caching.