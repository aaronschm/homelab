#!/bin/bash
set -e

echo "Step 1/6: Updating System..."
apt update && apt upgrade -y

echo "Step 2/6: Installing Apt-Cacher-NG..."
apt install apt-cacher-ng curl -y

echo "Step 3/6: Retrieving Repository Data from Admin LXC..."
read -p "Enter the Admin LXC IP Address: " ADMIN_IP
STATIC_DIR="/var/cache/apt-cacher-ng/_static"
mkdir -p "$STATIC_DIR"

# Files to get from Admin LXC
FILES=("admin_lxc.pub" "ssh-setup.sh" "k3s-control-plane-setup.sh" "k3s-agent-setup.sh" "cluster.conf")
for FILE in "${FILES[@]}"; do
    echo "Fetching $FILE..."
    curl -sSf "http://$ADMIN_IP:8000/$FILE" -o "$STATIC_DIR/$FILE"
    chmod 644 "$STATIC_DIR/$FILE"
done

# Fetch official K3s binaries
echo "Downloading K3s assets from official source..."
curl -sL "https://github.com/k3s-io/k3s/releases/download/v1.29.3+k3s1/k3s" -o "$STATIC_DIR/k3s"
curl -sL "https://get.k3s.io" -o "$STATIC_DIR/k3s-install.sh"
chmod +x "$STATIC_DIR/k3s" "$STATIC_DIR/k3s-install.sh"

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
echo " Web Dashboard: http://$IP_ADDR:3142/acng-stats/"
echo "----------------------------------------------------------------------"
echo " CLIENT BOOTSTRAP (K3S NODES):"
echo ""
echo " 1. Set Proxy (Run this first):"
echo " echo 'Acquire::http::Proxy \"http://$IP_ADDR:3142\";' | sudo tee /etc/apt/apt.conf.d/00proxy"
echo ""
echo " 2. Authorize Admin Key:"
echo " curl -sL http://$IP_ADDR:3142/static/admin_lxc.pub >> ~/.ssh/authorized_keys"
echo ""
echo " 1. Install Control Plane:"
echo " echo 'Acquire::http::Proxy \"http://$IP_ADDR:3142\";' > /etc/apt/apt.conf.d/00proxy && export http_proxy=http://$IP_ADDR:3142 && apt update && apt install curl -y && curl -sL http://$IP_ADDR:3142/static/k3s-control-plane-setup.sh | bash"
echo ""
echo " 2. Install Agent:"
echo " echo 'Acquire::http::Proxy \"http://$IP_ADDR:3142\";' > /etc/apt/apt.conf.d/00proxy && export http_proxy=http://$IP_ADDR:3142 && apt update && apt install curl -y && curl -sL http://$IP_ADDR:3142/static/k3s-agent-setup.sh | bash"
echo "======================================================================"