#!/bin/bash
# SSH Hardening Script for LXC containers

set -e
echo "=== SSH Hardening Script ==="
echo "Port: 2022"
echo "PasswordAuthentication: no"
echo "PubkeyAuthentication: yes"
echo ""

# 1. Disable socket activation
echo "[1/5] Disabling ssh.socket..."
systemctl disable ssh.socket 2>/dev/null
systemctl mask ssh.socket 2>/dev/null
systemctl stop ssh.socket 2>/dev/null

# 2. Backup original config
echo "[2/5] Backing up sshd_config..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# 3. Update sshd_config
echo "[3/5] Updating sshd_config..."
sed -i 's/^#Port 22$/Port 2022/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes$/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes$/PasswordAuthentication no/' /etc/ssh/sshd_config

# Ensure PubkeyAuthentication is enabled
if ! grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
fi

# Disable alternative auth methods
sed -i 's/^#ChallengeResponseAuthentication yes$/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication yes$/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# 4. Test syntax
echo "[4/5] Testing sshd config syntax..."
if sshd -t; then
    echo "✓ Config syntax valid"
else
    echo "✗ Config syntax error! Restoring backup..."
    cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
    exit 1
fi

# 5. Restart SSH service
echo "[5/5] Restarting SSH service..."
systemctl restart ssh.service

# Verify
sleep 1
echo ""
echo "=== Verification ==="
echo "Port listening:"
ss -tulpn | grep ssh
echo ""
echo "Config settings:"
grep -E "^Port|^PasswordAuthentication|^PubkeyAuthentication|^ChallengeResponseAuthentication" /etc/ssh/sshd_config
echo ""
echo "✓ Done! Test connection: ssh -p 2022 root@<container-ip>"