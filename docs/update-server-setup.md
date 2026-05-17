# **Update Server LXC** | What is it for?

Since K3s nodes in VLAN 25 cannot reach the internet directly, they cannot install or update packages.
To enable VLAN 25 to reach updates, the cacher-ng Server caches requested packages and sends them to the requestor.
Thus beeing an extended arm.
This server is not a full mirror; it caches only requested packages, saving storage.

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