# **Container Registry LXC** | What is it for?

The Container Registry LXC provides a local Docker-compatible container image repository for the K3s cluster.
Instead of pulling container images from Docker Hub or other remote registries, K3s nodes pull from this local registry, saving bandwidth and providing faster deployments.

This registry also acts as a single point of control for which images are available to the cluster, enabling air-gapped deployments and reducing dependency on external services.

## **How it works**

1. Container images are mirrored or pushed into the registry (e.g., Immich, MinIO, PostgreSQL images)
2. K3s is configured to pull images from this registry instead of remote sources
3. Images can be mirrored manually or on a schedule
4. Registry data is stored as Kubernetes objects and backed up via Velero to your main storage pool and friend's house

## **Requirements**

- Debian 13
- 2 vCores
- 2 GB RAM
- 100 GB Disk (adjust based on the images you plan to store)

## **Installation**

1. Update System
2. Install Docker
3. Run the registry service
4. Configure K3s to trust and use this registry

``` bash
apt update && apt upgrade -y
apt install curl -y
curl -sL https://raw.githubusercontent.com/aaronschm/homelab/refs/heads/main/scripts/registry-setup.sh | bash
```

## **Post-Setup Configuration**

### Mirror images into the registry

After the registry is running, mirror container images from Docker Hub:

```bash
# Example: Mirror Immich image
skopeo copy docker://ghcr.io/immich-app/immich:latest docker://registry-lxc:5000/immich:latest --dest-tls-verify=false

# Example: Mirror MinIO image
skopeo copy docker://minio/minio:latest docker://registry-lxc:5000/minio:latest --dest-tls-verify=false

# Example: Mirror PostgreSQL image
skopeo copy docker://postgres:15 docker://registry-lxc:5000/postgres:15 --dest-tls-verify=false
```

Replace `registry-lxc` with the actual hostname or IP of your registry LXC.

### Configure K3s to use the registry

On the K3s control plane, create or update `/etc/rancher/k3s/registries.yaml`:

```yaml
mirrors:
  docker.io:
    endpoint:
      - "http://registry-lxc:5000"
  ghcr.io:
    endpoint:
      - "http://registry-lxc:5000"

configs:
  registry-lxc:5000:
    tls:
      insecure: true
```

Then restart K3s:

```bash
systemctl restart k3s
```

### Verify the registry is working

```bash
# List images in the registry
curl -s http://registry-lxc:5000/v2/_catalog | jq .

# List tags for a specific image
curl -s http://registry-lxc:5000/v2/<image-name>/tags/list | jq .
```

## **Backup and Restore**

The registry data is stored in `/var/lib/registry` on the LXC.
This directory is backed up via Velero as part of the cluster backup strategy.

When deploying applications via Argo CD, reference images from the registry:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immich
spec:
  template:
    spec:
      containers:
      - name: immich
        image: registry-lxc:5000/immich:latest
```

## **Troubleshooting**

If K3s cannot pull images from the registry:

1. Verify the registry LXC is running: `ssh registry-lxc 'docker ps'`
2. Verify network connectivity from a K3s node: `curl -s http://registry-lxc:5000/v2/_catalog`
3. Check K3s logs: `journalctl -u k3s -f`
4. Verify `/etc/rancher/k3s/registries.yaml` is correct and restart K3s
