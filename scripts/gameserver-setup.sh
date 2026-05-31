#!/bin/bash
set -euo pipefail

echo "=== Gameserver (Pelican Wings) Bootstrap ==="

UPDATE_SERVER_IP="${UPDATE_SERVER_IP:-}"

if [ -z "$UPDATE_SERVER_IP" ]; then
    read -p "Enter the Update Server IP (leave blank for direct internet install): " UPDATE_SERVER_IP
fi

if [ -n "$UPDATE_SERVER_IP" ]; then
    STATIC_URL="http://$UPDATE_SERVER_IP:3142/static"
fi

# --- 1. Docker ---
echo "[1/5] Installing Docker CE..."
apt update
apt install -y curl ca-certificates gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker

# --- 2. Wings binary ---
echo "[2/5] Installing Pelican Wings..."
mkdir -p /etc/pelican /var/log/pelican

curl -fsSL "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_amd64" \
    -o /usr/local/bin/wings
chmod +x /usr/local/bin/wings

# --- 3. Systemd service ---
echo "[3/5] Creating Wings systemd service..."
cat > /etc/systemd/system/wings.service <<'EOF'
[Unit]
Description=Pelican Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/pelican
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wings

# --- 4. SSH hardening ---
echo "[4/5] Hardening SSH..."
if [ -n "$UPDATE_SERVER_IP" ]; then
    bash <(curl -fsSL "$STATIC_URL/ssh-setup.sh")
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    curl -fsSL "$STATIC_URL/admin_lxc.pub" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
else
    # Inline minimal SSH hardening when no update server is available
    sed -i 's/^#\?Port .*/Port 2022/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
    if ! grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    fi
    systemctl disable ssh.socket 2>/dev/null || true
    systemctl mask ssh.socket 2>/dev/null || true
    systemctl stop ssh.socket 2>/dev/null || true
    sshd -t && systemctl restart ssh.service
fi

# --- 5. Summary ---
echo ""
echo "======================================================================"
echo " GAMESERVER (WINGS) BOOTSTRAP COMPLETE"
echo "======================================================================"
echo ""
echo " Wings binary:   /usr/local/bin/wings"
echo " Config dir:     /etc/pelican/"
echo " Systemd:        wings.service (enabled, not yet started)"
echo " SSH port:       2022"
echo " Wings SFTP:     2023 (set sftp.bind_port in config.yml)"
echo ""
echo " Next steps:"
echo "  1. Add this node in the Pelican Panel"
echo "  2. Copy the generated config.yml to /etc/pelican/config.yml"
echo "  3. Set sftp.bind_port to 2023 in config.yml"
echo "  4. Open game server ports in the firewall"
echo "  5. Start Wings: systemctl start wings"
echo ""
echo "======================================================================"
