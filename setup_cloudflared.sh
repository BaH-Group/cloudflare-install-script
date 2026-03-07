#!/bin/bash

echo "Starting Interactive Cloudflared Setup..."

# 1. Verify Admin Access Upfront
echo "Verifying admin access (required for creating config files and services)..."
sudo -v || { echo "Admin access is required to proceed. Exiting."; exit 1; }

echo "------------------------------------------------"
echo "Cloudflared Auto-Installer (Architecture Aware)"
echo "------------------------------------------------"

# 2. Gather Variables Interactively
read -p "Enter Tunnel Name (e.g., my-tunnel): " TUNNEL_NAME
read -p "Enter Full Hostname (e.g., ssh9.medikai.uz): " HOST_NAME
read -p "Enter SSH User on server (e.g., root): " SSH_USER
read -p "Enter a Nickname for this connection (e.g., trash): " NICKNAME

# 3. Detect Architecture and Install [cite: 5, 7, 8]
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    DEB_FILE="cloudflared-linux-arm64.deb"
else
    DEB_FILE="cloudflared-linux-amd64.deb"
fi

echo "Detected $ARCH. Downloading $DEB_FILE..."
wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/$DEB_FILE" [cite: 6, 7]
sudo dpkg -i "$DEB_FILE" [cite: 8]

# 4. Tunnel Authentication and Creation [cite: 9, 10, 11, 12]
echo "Please follow the link below to login:"
cloudflared tunnel login [cite: 10]
cloudflared tunnel create "$TUNNEL_NAME" [cite: 12]

# Get the Tunnel ID automatically
TUNNEL_ID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')
[ -z "$TUNNEL_ID" ] && { echo "Failed to get Tunnel ID"; exit 1; }

# 5. Create Configuration [cite: 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
sudo mkdir -p /etc/cloudflared [cite: 14]
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json
ingress:
  - hostname: $HOST_NAME
    service: ssh://localhost:22
  - service: http_status:404
EOF

# 6. Route DNS and Start Service [cite: 23, 24, 27, 28, 29, 30]
cloudflared tunnel route dns "$TUNNEL_NAME" "$HOST_NAME" 
sudo cloudflared service install [cite: 28]
sudo systemctl start cloudflared [cite: 29]
sudo systemctl enable cloudflared [cite: 30]

echo "------------------------------------------------"
echo "✅ SERVER SETUP COMPLETE"
echo "------------------------------------------------"
echo "To connect from your LOCAL machine, add this to your ~/.ssh/config:"
echo ""
echo "Host $NICKNAME"
echo "  User $SSH_USER"
echo "  ProxyCommand cloudflared access ssh --hostname $HOST_NAME"
echo ""
echo "Then, simply run: ssh $NICKNAME"
echo "------------------------------------------------"

# 7. Show Status and Logs [cite: 31, 33]
sudo systemctl status cloudflared --no-pager [cite: 31]
journalctl -u cloudflared -f [cite: 33]