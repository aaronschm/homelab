#!/bin/bash
set -e

echo "=== K3s Load Balancer Bootstrap ==="

# 1. Get the source of truth
if [ -z "$UPDATE_SERVER_IP" ]; then
    read -p "Enter the Update Server IP: " UPDATE_SERVER_IP
fi

STATIC_URL="http://$UPDATE_SERVER_IP:3142/static"

# 2. Configure Local Package Proxy
echo "[1/6] Pointing Apt to Update Server"
echo "Acquire::http::Proxy \"http://$UPDATE_SERVER_IP:3142\";" > \
    /etc/apt/apt.conf.d/00proxy

# 3. Fetch Cluster Config
echo "[2/6] Fetching cluster.conf"
# Sourcing directly from the update server to get latest IPs
source <(curl -sSf "$STATIC_URL/cluster.conf")

# 4. System Installation
echo "[3/6] Installing Nginx with Stream Support"
apt update
apt install nginx nginx-mod-stream curl -y

# 5. Nginx Configuration (Layer 4 TCP Proxy)
echo "[4/6] Configuring TCP Load Balancing"
cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

stream {
    upstream k3s_api {
$(for ip in $CONTROL_PLANE_IPS; do
    echo "        server $ip:6443 max_fails=3 fail_timeout=30s;"
done)
    }

    server {
        listen 6443;
        proxy_pass k3s_api;
        proxy_timeout 1h;
        proxy_connect_timeout 5s;
    }
}
EOF

# 6. Apply Security and Admin Access
echo "[5/6] Hardening SSH and authorizing Admin key..."
curl -sL "$STATIC_URL/ssh-setup.sh" | bash

mkdir -p ~/.ssh && chmod 700 ~/.ssh
curl -sL "$STATIC_URL/admin_lxc.pub" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 7. Finalize
echo "[6/6] Restarting Nginx..."
nginx -t && systemctl restart nginx
systemctl enable nginx

echo ""
echo "======================================================================"
echo " LOAD BALANCER DEPLOYED"
echo "======================================================================"
echo " Entry Point:  $LOAD_BALANCER_IP:6443"
echo " Backends:    $CONTROL_PLANE_IPS"
echo " Status:      $(systemctl is-active nginx)"
echo "======================================================================"