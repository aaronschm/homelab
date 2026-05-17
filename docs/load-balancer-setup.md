# **Load Balancer** | What is it for?

When more than One Control-Plane (Master) Node exist, HA can only be achieved by a Load Balancer, who directs the traffic from the Agents steady across the whole Cluster.
Here Nginx has been selected.

## **Requirements**

- Debian 13
- 1 vCores
- 2 GB RAM
- 10 GB Disk

## **Installation**

``` bash
pt update && apt upgrade -y
apt install curl -y
curl -sL https://raw.githubusercontent.com/aaronschm/homelab/refs/heads/main/scripts/load-balancer-setup.sh | bash
```
