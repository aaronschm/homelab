# **K3s Server** | What is it for?

K3s is a lightweight kubernetes version written in Go.
It manages stateless containers, statefull DB and includes traefik.

### Control-Plane (Master)

The Control-Plane is a Master Node, which manages the Agents and Databases.
It can create or destroy containers across the entire Kubernetes cluster.

### Agent (Worker)

The agent is the workhorse where containers run.

## **Requirements**

### Control-Plane 
- Debian 13
- 2 vCores
- 6 GB RAM
- 50 GB Disk

### Agent 
- Debian 13
- 5 vCores
- 16 GB RAM
- 50 GB Disk

## **Installation**
### Install command for K3s Control-Plane
``` bash
export IP=10.10.20.100; echo "Acquire::http::Proxy \"http://$IP:3142\";" > /etc/apt/apt.conf.d/00proxy && export http_proxy=http://$IP:3142 && apt update && apt install curl -y && curl -sL http://$IP:3142/static/k3s-control-plane-setup.sh | bash
```

### Install command for K3s Agent
``` bash
export IP=10.10.20.100; echo "Acquire::http::Proxy \"http://$IP:3142\";" > /etc/apt/apt.conf.d/00proxy && export http_proxy=http://$IP:3142 && apt update && apt install curl -y && curl -sL http://$IP:3142/static/k3s-agent-setup.sh | bash
```