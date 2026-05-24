#!/bin/bash
# update-server-setup.sh
set -e

echo "Step 1/6: Updating System..."
apt update && apt upgrade -y

echo "Step 2/6: Installing Apt-Cacher-NG..."
apt install apt-cacher-ng curl -y

echo "Step 3/6: Retrieving Repository Data from Admin LXC..."
read -p "Enter the Admin LXC IP Address: " ADMIN_IP
STATIC_DIR="/var/cache/apt-cacher-ng/_static"
mkdir -p "$STATIC_DIR"

FILES=("admin_lxc.pub" "ssh-setup.sh" "cluster.conf" "k3s-control-plane-setup.sh" "k3s-agent-setup.sh" "load-balancer-setup.sh" "dmz-reverse-proxy-setup.sh" "registry-setup.sh" "db-setup.sh" "minio-setup.sh")

for FILE in "${FILES[@]}"; do
    echo "Fetching $FILE..."
    curl -sSf "http://$ADMIN_IP:8000/$FILE" -o "$STATIC_DIR/$FILE"
    chmod 644 "$STATIC_DIR/$FILE"
done

# Fetch official binaries
echo "Downloading K3s and MinIO assets..."
curl -sL "https://github.com/k3s-io/k3s/releases/download/v1.29.3+k3s1/k3s" -o "$STATIC_DIR/k3s"
curl -sL "https://get.k3s.io" -o "$STATIC_DIR/k3s-install.sh"
curl -sL "https://dl.min.io/server/minio/release/linux-amd64/minio" -o "$STATIC_DIR/minio"
chmod +x "$STATIC_DIR/k3s" "$STATIC_DIR/k3s-install.sh" "$STATIC_DIR/minio"

echo "Step 4/6: Configuring Cache Settings..."
{
    echo "ExposeOriginInfo: 1"
    echo "AdminPassword: admin"
    echo "PassThroughPattern: .*"
} >> /etc/apt-cacher-ng/acng.conf

echo "Step 5/6: Hardening SSH..."
bash "$STATIC_DIR/ssh-setup.sh"

echo "Step 6/6: Restarting Services..."
systemctl enable apt-cacher-ng
systemctl restart apt-cacher-ng

IP_ADDR=$(hostname -I | awk '{print $1}')

echo ""
echo "======================================================================"
echo " SETUP COMPLETE: INTERNAL REPOSITORY READY"
echo "======================================================================"
echo " 1. LOAD BALANCER:"
echo " echo 'Acquire::http::Proxy \"http://$IP_ADDR:3142\";' > /etc/apt/apt.conf.d/00proxy && export http_proxy=http://$IP_ADDR:3142 && apt update && apt install curl -y && curl -sL http://$IP_ADDR:3142/static/load-balancer-setup.sh | bash"
echo ""
echo " 2. CONTROL PLANE:"
echo " echo 'Acquire::http::Proxy \"http://$IP_ADDR:3142\";' > /etc/apt/apt.conf.d/00proxy && export http_proxy=http://$IP_ADDR:3142 && apt update && apt install curl -y && curl -sL http://$IP_ADDR:3142/static/k3s-control-plane-setup.sh | bash"
echo ""
echo " 3. AGENT:"
echo " echo 'Acquire::http::Proxy \"http://$IP_ADDR:3142\";' > /etc/apt/apt.conf.d/00proxy && export http_proxy=http://$IP_ADDR:3142 && apt update && apt install curl -y && curl -sL http://$IP_ADDR:3142/static/k3s-agent-setup.sh | bash"
echo ""
echo " 4. DMZ REVERSE PROXY:"
echo " apt update && apt install curl -y && curl -sL http://$IP_ADDR:3142/static/dmz-reverse-proxy-setup.sh | UPDATE_SERVER_IP=$IP_ADDR bash"
echo ""
echo " 5. CONTAINER REGISTRY:"
echo " apt update && apt install curl -y && curl -sL http://$IP_ADDR:3142/static/registry-setup.sh | bash"
echo ""
echo "======================================================================"