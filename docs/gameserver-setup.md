# **Gameserver VM** | Pelican Wings

This VM runs [Pelican Wings](https://pelican.dev) in the DMZ to host game servers. The Pelican Panel (web UI) runs inside the cluster (VLAN 25) and manages this node remotely via Traefik.

Wings uses Docker to isolate each game server instance and includes a built-in SFTP server for file management through the panel.

## **Requirements**

- Debian 13
- 6 vCores
- 32 GB RAM (ballooning enabled)
- 100 GB+ Disk (depends on game servers)

## **Network**

| Role | VLAN | IP |
| :--- | :--- | :--- |
| Gameserver (Wings) | 24 – DMZ | `10.10.24.20` |
| Pelican Panel | 25 – Cluster | Exposed via Traefik |

### Ports

| Port | Protocol | Purpose |
| :--- | :--- | :--- |
| 2022 | TCP | SSH (management) |
| 2023 | TCP | Wings SFTP (file access via panel) |
| 443 | TCP | Wings daemon API (panel ↔ Wings) |
| 25565–25665 | TCP/UDP | Game server ports (adjust as needed) |

## **Installation**

### From the Update Server

```bash
apt update && apt install curl -y && curl -sL http://10.10.20.100:3142/static/gameserver-setup.sh | UPDATE_SERVER_IP=10.10.20.100 bash
```

### From the public repository

```bash
apt update && apt upgrade -y
apt install curl -y
curl -sL https://raw.githubusercontent.com/aaronschm/homelab/refs/heads/main/scripts/gameserver-setup.sh | bash
```

## **Script Behavior**

The script performs these actions:

- Installs Docker CE and enables the service
- Downloads the Pelican Wings binary to `/usr/local/bin/wings`
- Creates a systemd service (`wings.service`) — enabled but **not started**
- Hardens SSH (port 2022, key-only authentication)
- Creates the `/etc/pelican/` config directory

## **Post-Install**

1. Log into the Pelican Panel and add a new node.
2. Copy the generated `config.yml` to `/etc/pelican/config.yml`.
3. Set the SFTP bind port to `2023` in the config (default 2022 conflicts with SSH):

   ```yaml
   sftp:
     bind_port: 2023
   ```

4. Open game server ports in the router/firewall as needed.
5. Start Wings:

   ```bash
   systemctl start wings
   ```

## **Notes**

- The Pelican Panel is deployed inside the cluster (VLAN 25) and reached through Traefik in the DMZ.
- Wings connects **outbound** to the panel URL for configuration and status reporting.
- The panel also connects **inbound** to Wings on port 443 for real-time management.
- Wings SFTP runs on port **2023** instead of the default 2022, because SSH already occupies that port.
- Game server port ranges must be opened in the firewall (WAN → DMZ) as needed per game.
- Ballooning is enabled on this VM — Proxmox can reclaim unused memory when other VMs are under pressure.
