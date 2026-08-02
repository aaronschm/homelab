# IsarCloud Router Dashboard

A lightweight, custom React/Node.js web application built to manage a MikroTik RouterOS (v7) device behind an Authentik proxy.

## Features

- **WireGuard**: Toggle tunnels, create new peers, generate configs, and display QR codes for mobile devices.
- **Port Forwarding (NAT)**: View and create Destination NAT rules.
- **VLAN Management**: Modify the PVID (untagged VLAN ID) of bridge ports.
- **Client Tracking**: View all ARP and DHCP leases, and assign custom persistent names to devices.
- **Live Interfaces**: View all physical and logical interfaces and their live status.

## Deployment

The containers are automatically built and published to GHCR via GitHub Actions (`.github/workflows/docker-publish.yml`).

Argo CD handles the deployment to the `router-dashboard` namespace.
