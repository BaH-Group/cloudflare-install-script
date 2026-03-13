#!/bin/bash

echo "------------------------------------------------"
echo "Cloudflared Auto-Installer"
echo "------------------------------------------------"

# 1. Verify Admin Access
sudo -v || { echo "Admin access is required. Exiting."; exit 1; }

# 2. Gather Variables Interactively
read -p "Enter Tunnel Name (e.g., my-tunnel): " TUNNEL_NAME
read -p "Enter Full Hostname (e.g., ssh10.medikai.uz): " HOST_NAME
read -p "Enter SSH User on server (e.g., pi): " SSH_USER
read -p "Enter a Nickname for local SSH config (e.g., trash): " NICKNAME

# 3. Detect Architecture and Install
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    DEB_FILE="cloudflared-linux-arm64.deb"
else
    DEB_FILE="cloudflared-linux-amd64.deb"
fi

echo "Detected architecture: $ARCH. Downloading $DEB_FILE..."
# Ensure any corrupted previous downloads are removed
rm -f "$DEB_FILE"
wget -q --show-progress "https://github.com/cloudflare/cloudflared/releases/latest/download/$DEB_FILE"

echo "Installing cloudflared..."
sudo dpkg -i "$DEB_FILE"

# 4. Tunnel Authentication and Creation
echo "Please follow the link below to login:"
cloudflared tunnel login

echo "Creating tunnel..."
cloudflared tunnel create "$TUNNEL_NAME"

# Get the Tunnel ID automatically
TUNNEL_ID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')
if [ -z "$TUNNEL_ID" ]; then
    echo "Failed to get Tunnel ID. Exiting."
    exit 1
fi

# 5. Create Configuration
echo "Creating configuration file..."
sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json
ingress:
  - hostname: $HOST_NAME
    service: ssh://localhost:22
  - service: http_status:404
EOF

# 6. Route DNS and Start Service
echo "Routing DNS..."
cloudflared tunnel route dns "$TUNNEL_NAME" "$HOST_NAME"

echo "Installing and starting service..."
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

echo "------------------------------------------------"
echo "✅ SERVER SETUP COMPLETE"
echo "------------------------------------------------"
echo "To connect from your LOCAL machine, you have two options:"
echo ""
echo "OPTION 1: Add this exact block to your ~/.ssh/config file:"
echo "------------------------------------------------"
echo "Host $NICKNAME"
echo "  User $SSH_USER"
echo "  ProxyCommand cloudflared access ssh --hostname $HOST_NAME"
echo "------------------------------------------------"
echo "Then, you can connect simply by typing: ssh $NICKNAME"
echo ""
echo "OPTION 2: Run this one-liner directly in your terminal:"
echo "------------------------------------------------"
echo "ssh -o ProxyCommand=\"cloudflared access ssh --hostname $HOST_NAME\" $SSH_USER@$HOST_NAME"
echo "------------------------------------------------"

# 7. Show Status and Logs
sudo systemctl status cloudflared --no-pager
journalctl -u cloudflared -f
