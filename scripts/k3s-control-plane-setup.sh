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
FIRST_MASTER=$(echo $CONTROL_PLANE_IPS | awk '{print $1}')

export INSTALL_K3S_SKIP_DOWNLOAD=true
export K3S_TOKEN="$K3S_TOKEN"

if [ "$MY_IP" == "$FIRST_MASTER" ]; then
    echo "Bootstrap: Initializing K3s Cluster..."
    export INSTALL_K3S_EXEC="server --cluster-init --write-kubeconfig-mode 644 --node-ip=$MY_IP --tls-san=$LOAD_BALANCER_IP"
else
    echo "Joining: Connecting to first Master..."
    export K3S_URL="https://$FIRST_MASTER:6443"
    export INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644 --node-ip=$MY_IP --tls-san=$LOAD_BALANCER_IP"
fi

sh /tmp/k3s-install.sh