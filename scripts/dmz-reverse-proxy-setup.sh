#!/bin/bash
set -euo pipefail

echo "=== DMZ Reverse Proxy Bootstrap ==="

TRAEFIK_HOSTNAME="${TRAEFIK_HOSTNAME:-}"
TRAEFIK_EMAIL="${TRAEFIK_EMAIL:-}"
UPDATE_SERVER_IP="${UPDATE_SERVER_IP:-}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"

if [ -z "$TRAEFIK_HOSTNAME" ]; then
    read -p "Enter the public hostname for this proxy (example.com): " TRAEFIK_HOSTNAME
fi

if [ -z "$TRAEFIK_EMAIL" ]; then
    read -p "Enter an email address for ACME certificate registration: " TRAEFIK_EMAIL
fi

if [ -z "$UPDATE_SERVER_IP" ]; then
    read -p "Enter the Update Server IP (leave blank for direct internet install): " UPDATE_SERVER_IP
fi

if [ -n "$UPDATE_SERVER_IP" ]; then
    echo "[1/6] Configuring apt to use update server $UPDATE_SERVER_IP"
    cat > /etc/apt/apt.conf.d/00proxy <<EOF
Acquire::http::Proxy "http://$UPDATE_SERVER_IP:3142";
EOF
    STATIC_URL="http://$UPDATE_SERVER_IP:3142/static"
fi

echo "[2/6] Installing prerequisites"
apt update
apt install -y curl ca-certificates tzdata

install_traefik_from_apt() {
    echo "[3/6] Attempting to install Traefik from apt"
    if apt-get install -y traefik; then
        return 0
    fi
    return 1
}

install_traefik_from_binary() {
    echo "[3/6] Installing Traefik from binary fallback"
    TRAEFIK_VERSION="v3.0.8"
    ARCH="amd64"
    TMPDIR=$(mktemp -d)

    curl -fsSL "https://github.com/traefik/traefik/releases/download/$TRAEFIK_VERSION/traefik_${TRAEFIK_VERSION#v}_linux_${ARCH}.tar.gz" -o "$TMPDIR/traefik.tar.gz"
    tar -xzf "$TMPDIR/traefik.tar.gz" -C "$TMPDIR"
    install -Dm755 "$TMPDIR/traefik" /usr/local/bin/traefik
    rm -rf "$TMPDIR"

    cat > /etc/systemd/system/traefik.service <<'EOF'
[Unit]
Description=Traefik Reverse Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

if ! install_traefik_from_apt; then
    install_traefik_from_binary
fi

mkdir -p /etc/traefik

cat > /etc/traefik/traefik.yml <<EOF
entryPoints:
  web:
    address: ":${HTTP_PORT}"
  websecure:
    address: ":${HTTPS_PORT}"

certificatesResolvers:
  le:
    acme:
      email: "${TRAEFIK_EMAIL}"
      storage: "/etc/traefik/acme.json"
      httpChallenge:
        entryPoint: web

providers:
  file:
    filename: "/etc/traefik/dynamic.yml"
    watch: true

log:
  level: INFO

accessLog: {}
EOF

cat > /etc/traefik/dynamic.yml <<EOF
http:
  routers:
    placeholder-router:
      rule: "Host(`$TRAEFIK_HOSTNAME`)"
      entryPoints:
        - websecure
      service: placeholder-service
      tls:
        certResolver: le

  services:
    placeholder-service:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:8080"
EOF

touch /etc/traefik/acme.json
chmod 600 /etc/traefik/acme.json

if [ -n "$UPDATE_SERVER_IP" ]; then
    echo "[4/6] Installing SSH hardening and Admin public key"
    bash <(curl -fsSL "$STATIC_URL/ssh-setup.sh")
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    curl -fsSL "$STATIC_URL/admin_lxc.pub" > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

echo "[5/6] Enabling and starting Traefik"
if systemctl is-enabled --quiet traefik; then
    systemctl daemon-reload
    systemctl restart traefik
else
    systemctl daemon-reload
    systemctl enable --now traefik
fi

cat <<EOF
DMZ reverse proxy bootstrap complete.

Traefik is installed and running.

Configuration files:
- /etc/traefik/traefik.yml
- /etc/traefik/dynamic.yml
- /etc/traefik/acme.json

Next steps:
- Update /etc/traefik/dynamic.yml with your backend services and backend IPs.
- Allow TCP 80 and 443 from the WAN to this DMZ LXC.
- Allow this DMZ LXC to access the internal backend service ports.

Example router for an internal service:

http:
  routers:
    app-router:
      rule: "Host(`app.$TRAEFIK_HOSTNAME`)"
      entryPoints:
        - websecure
      service: app-service
      tls:
        certResolver: le

  services:
    app-service:
      loadBalancer:
        servers:
          - url: "http://10.10.25.10:8080"

EOF
