# **Homelab** | Why I build it.

This project was made, to learn kubernetes and enhance my Homeserver Setup.

## Where I started.

### Start
Ive watched a few Videos about Kubernets, K3s and know how to intialize a k3s Setup.
Thats about it, no Idea how managing the Container-Services inside will actually go.

## End



## What it shall achieve.

I want the option to easily add another Server to achieve somewhat of HA. A redundand Storage Setup would be needed, but Ceph or Longhorn require too much resources (especially in 2026), which is why I settled on a "normal" RaidZ1 Pool managed by MinIO to be able to easily add a new Pool and thus have upgradable seemless Storage.
I'll host a PostgreSQL Server for the statless appliances.

## Which services are required.

Traefik will work as reverse proxy and load balancer.
K3s will work as a Orchestrator and allow sclaing.
PostgreSQL will be the DB.
A selfbuild LXC will host the DynDNS.
A managing LXC will play the role of admin and give K3s its orders.
Three VLANs allow the added Security of keeping K3s away from Internet access, Traefik sits in a DMZ and talks to the internet, then routes securely to K3s.
An updae LXC will fetch and distribute every needed packet to K3s and its Containers.

## What I added and why.

- `docs/network-setup.md`: documents the VLAN layout and firewall rules that keep the cluster isolated while allowing the minimum traffic needed for package updates and Traefik ingress.
- `docs/admin-setup.md` and `scripts/admin-setup.sh`: explains the Admin LXC purpose and how it replaces local workstation dependencies with a centralized management container.
- `docs/update-server-setup.md` and `scripts/update-server-setup.sh`: create the apt-cacher-ng Update Server, which allows cluster nodes in VLAN 25 to fetch packages and bootstrap scripts without direct internet access.
- `docs/dmz-reverse-proxy.md` and `scripts/dmz-reverse-proxy-setup.sh`: bootstrap a dedicated DMZ reverse proxy LXC for public HTTP/S ingress.
- `docs/registry-setup.md` and `scripts/registry-setup.sh`: sets up a local Docker registry for mirroring container images, allowing K3s nodes to pull images locally without direct internet access.
- `docs/k3s-setup.md`: describes K3s control plane and agent requirements along with the proxy command to bootstrap nodes through the update server.
Following the setup order will result in less effort needed.
- `LICENSE`: A professional MIT license for the repository.

## Setup order.

1. **Admin LXC**
   - Create the Admin container first.
   - Follow the Setup described in`docs/admin-setup.md` inside the LXC.
   - This gives you the management environment, SSH key, and repo access required for later steps.

2. **Update Server**
   - Create the Update Server container next.
   - Run the Setup procedure from `docs/update-server-setup.md` inside the LXC.
   - This installs apt-cacher-ng and fetches the client bootstrap assets for the cluster.

3. **DMZ Reverse Proxy**
   - Create the DMZ reverse proxy LXC.
   - Run the setup script from `docs/dmz-reverse-proxy.md` and `scripts/dmz-reverse-proxy-setup.sh`.
   - Allow inbound TCP 80 and 443 to the proxy and allow the proxy to reach your backend services.

4. **Load Balancer**
   - Deploy the Nginx load balancer that will front the cluster.
   - Follow the Setup descriped in `docs/load-balancer-setup.md` inside the LXC.

5. **Container Registry**
   - Create the Container Registry LXC.
   - Run the setup script from `docs/registry-setup.md` and `scripts/registry-setup.sh`.
   - This provides a local Docker registry where K3s nodes can pull container images without direct internet access.
   - Mirror images (Immich, MinIO, PostgreSQL, etc.) into the registry before deploying applications.

6. **K3s VMs**
   - Create the control plane and agent VMs.
   - Use the proxy configuration in `docs/k3s-setup.md` to point them at the Update Server for package and script access.
   - Make sure VLAN 25 nodes can reach the Update Server on port `3142`, and the load balancer on port `6443`.
   - Configure the K3s control plane to use the Container Registry for all image pulls (see `docs/registry-setup.md`).

7. **Work in progress**
