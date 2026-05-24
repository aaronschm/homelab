# **Update Server LXC** | What is it for?

Since K3s nodes in VLAN 25 cannot reach the internet directly, they cannot install or update packages.
To enable VLAN 25 to reach updates, the cacher-ng Server caches requested packages and sends them to the requestor.
Thus beeing an extended arm.
This server is not a full mirror; it caches only requested packages, saving storage.

If your cluster nodes cannot reach the public internet directly, the Update Server should also stage any self-hosted installer binaries that are needed during bootstrap (for example, the MinIO binary used by your internal service deployment scripts). If VLAN 25 can reach the internet through a controlled proxy, that binary can be downloaded on demand instead.

## **Related Services**

The Update Server also stages bootstrap scripts for other infrastructure components:
- Container Registry LXC setup script
- Load Balancer setup script
- K3s Control Plane and Agent setup scripts
- DMZ Reverse Proxy setup script

See `docs/registry-setup.md` for details on the Container Registry LXC, which is deployed after the Update Server.

## **Requirements**

- Debian 13
- 1 vCore
- 1 GB RAM
- 40 GB Disk

## **Installation**

1. Update System
2. Install tools (Curl and apt-cacher-ng)


``` bash
apt update && apt upgrade -y
apt install curl -y
curl -sL https://raw.githubusercontent.com/aaronschm/homelab/refs/heads/main/scripts/update-server-setup.sh | bash
```