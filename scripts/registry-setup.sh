#!/bin/bash
# registry-setup.sh - Container Registry LXC Setup
set -e

echo "Step 1/5: Updating System..."
apt update && apt upgrade -y

echo "Step 2/5: Installing Docker and Tools..."
apt install curl docker.io skopeo -y

echo "Step 3/5: Starting Docker Service..."
systemctl enable docker
systemctl start docker

echo "Step 4/5: Running Docker Registry Container..."
docker run -d \
  --name registry \
  --restart always \
  -p 5000:5000 \
  -v /var/lib/registry:/var/lib/registry \
  registry:2

echo "Step 5/5: Hardening SSH..."
STATIC_DIR="/tmp"
mkdir -p "$STATIC_DIR"

# Fetch SSH setup script from admin LXC
read -p "Enter the Admin LXC IP Address: " ADMIN_IP
if curl -sSf "http://$ADMIN_IP:8000/ssh-setup.sh" -o "$STATIC_DIR/ssh-setup.sh" 2>/dev/null; then
    bash "$STATIC_DIR/ssh-setup.sh"
else
    echo "Warning: Could not fetch ssh-setup.sh from Admin LXC. SSH hardening skipped."
    echo "You can manually run: curl -sL https://raw.githubusercontent.com/aaronschm/homelab/refs/heads/main/scripts/ssh-setup.sh | bash"
fi

IP_ADDR=$(hostname -I | awk '{print $1}')

echo ""
echo "======================================================================"
echo " SETUP COMPLETE: CONTAINER REGISTRY READY"
echo "======================================================================"
echo " Registry URL: http://$IP_ADDR:5000"
echo ""
echo " To mirror images from Docker Hub:"
echo " skopeo copy docker://ghcr.io/immich-app/immich:latest \\"
echo "   docker://$IP_ADDR:5000/immich:latest --dest-tls-verify=false"
echo ""
echo " To configure K3s, create /etc/rancher/k3s/registries.yaml on the"
echo " control plane with the registry endpoint."
echo ""
echo " See docs/registry-setup.md for full configuration details."
echo "======================================================================"
