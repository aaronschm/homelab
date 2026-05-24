# DMZ Reverse Proxy | Traefik

This document describes a dedicated DMZ reverse proxy LXC for fronting public HTTP/S traffic into your homelab.

## Recommended proxy

Use **Traefik** for this role.

Why Traefik?
- It is well suited for an Internet-facing DMZ proxy.
- It supports HTTPS with ACME and LetsEncrypt out of the box.
- It can route multiple hostnames to different backend services.
- It matches the existing architecture in this repository.

If you only need a simple static host-to-backend proxy and do not need ACME or dynamic routing, **Nginx** is also a solid alternative.

## Purpose

The DMZ reverse proxy lives in a separate VLAN and accepts traffic from the Internet.
It then forwards HTTP/S traffic to backend services inside the cluster VLAN or other internal networks.

Typical traffic flow:
- Internet -> DMZ Proxy (LXC) -> Cluster service

## Requirements

- Debian 13 or later on the DMZ LXC
- Static DMZ IP address assigned by your router/firewall
- Firewall rules that allow inbound TCP 80/443 to the DMZ LXC
- Firewall rules that allow the DMZ LXC to reach backend service ports in VLAN 25
- Public DNS for the hostname you want to expose

## Recommended network layout

| Role | VLAN | Example IP | Notes |
| --- | --- | --- | --- |
| DMZ reverse proxy | 24 | `10.10.24.10` | Public-facing proxy LXC |
| K3s cluster | 25 | `10.10.25.0/24` | Internal backend services |

## Setup

1. Create the LXC in the DMZ VLAN.
2. Assign the container a static DMZ IP.
3. Ensure the router/firewall forwards TCP 80 and 443 to the LXC.
4. Run the bootstrap script from this repository:

```bash
bash /path/to/homelab/scripts/dmz-reverse-proxy-setup.sh
```

### Bootstrap from the Update Server

If your Update Server is already installed and reachable from the DMZ, copy and run this command on the DMZ LXC:

```bash
curl -sL http://10.10.20.100:3142/static/dmz-reverse-proxy-setup.sh | UPDATE_SERVER_IP=10.10.20.100 bash
```

This will activate the DMZ setup via the Update Server, install Traefik, install the SSH hardening script, and add the Admin LXC / Ansible server public key to `/root/.ssh/authorized_keys`.

If you prefer to bootstrap from the public repository, copy the script into the LXC first.

## Script behavior

The script performs these actions:
- installs Traefik (via apt if available, with a binary fallback)
- creates `/etc/traefik/traefik.yml`
- creates `/etc/traefik/dynamic.yml`
- creates `/etc/traefik/acme.json`
- enables and starts the Traefik service

## Example configuration

The bootstrap script creates a placeholder `dynamic.yml` with a sample router.
After bootstrapping, edit `/etc/traefik/dynamic.yml` and add backends for your services.

Example service route:

```yaml
http:
  routers:
    app-router:
      rule: "Host(`app.example.com`)"
      entryPoints:
        - websecure
      service: app-service
      tls:
        certResolver: le

  services:
    app-service:
      loadBalancer:
        servers:
          - url: "http://10.10.25.10:8080"
```

## Notes

- If you use LetsEncrypt, Traefik will request certificates from the public Internet.
- If you do not want automatic certificates, set `tls: {}` in your router definitions and manage certs manually.
- Keep the DMZ reverse proxy as minimal as possible: only expose 80/443 and only allow backend access to the services you actually need.

## Security

- Do not expose internal Kubernetes ports directly to the Internet.
- Use firewall rules to restrict DMZ access to only the DMZ proxy and trusted management systems.
- Keep the DMZ LXC up to date and monitor Traefik logs for unexpected traffic.
