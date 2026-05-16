# Homelab | Why I build it.

This project was made, to learn kubernetes and enhance my Homeserver Setup.

# Homelab | Where I started.

## Start
Ive watched a few Videos about Kubernets, K3s and know how to intialize a k3s Setup.
Thats about it, no Idea how managing the Container-Services inside will actually go.

## End

---

# Homelab | What it shall achieve.

I want the option to easily add another Server to achieve somewhat of HA. A redundand Storage Setup would be needed, but Ceph or Longhorn require too much resources (especially in 2026), which is why I settled on a "normal" RaidZ1 Pool managed by MinIO to be able to easily add a new Pool and thus have upgradable seemless Storage.
I'll host a PostgreSQL Server for the statless appliances.

# Homelab | Which services are required.

Traefik will work as reverse proxy and load balancer.
K3s will work as a Orchestrator and allow sclaing.
PostgreSQL will be the DB.
A selfbuild LXC will host the DynDNS.
A managing LXC will play the role of admin and give K3s its orders.
Three VLANs allow the added Security of keeping K3s away from Internet access, Traefik sits in a DMZ and talks to the internet, then routes securely to K3s.
An updae LXC will fetch and distribute every needed packet to K3s and its Containers.