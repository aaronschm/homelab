#!/bin/bash
set -e

UPDATE_SERVER=$(grep -oP 'http://\K[0-9.]+' /etc/apt/apt.conf.d/00proxy)
STATIC_URL="http://$UPDATE_SERVER:3142/static"

source <(curl -sL "$STATIC_URL/cluster.conf")

# Overwrite authorized_keys with Admin Public Key
mkdir -p ~/.ssh && chmod 700 ~/.ssh
curl -sL "$STATIC_URL/admin_lxc.pub" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Setup Binaries
curl -sL "$STATIC_URL/k3s" -o /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s
curl -sL "$STATIC_URL/k3s-install.sh" -o /tmp/k3s-install.sh

MY_IP=$(hostname -I | awk '{print $1}')

export INSTALL_K3S_SKIP_DOWNLOAD=true
export K3S_TOKEN="$K3S_TOKEN"
# Point to the Load Balancer instead of a single Master
export K3S_URL="https://$LOAD_BALANCER_IP:6443"
export INSTALL_K3S_EXEC="agent --node-ip=$MY_IP"

sh /tmp/k3s-install.sh