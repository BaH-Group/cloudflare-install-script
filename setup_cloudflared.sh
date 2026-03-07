#!/bin/bash

echo "Starting Interactive Cloudflared Setup..."

# 1. Verify Admin Access Upfront
echo "Verifying admin access (required for creating config files and services)..."
sudo -v || { echo "Admin access is required to proceed. Exiting."; exit 1; }

# 2. Gather variables interactively
echo "----------------------------------------"
read -p "Enter the tunnel name (e.g., my-tunnel): " TUNNEL_NAME

echo ""
echo "IMPORTANT: The hostname must be a domain or subdomain you already manage in Cloudflare."
read -p "Enter the hostname to route (e.g., ssh.medikai.uz): " HOST_NAME

echo ""
read -p "Enter the SSH username you will use to log into this server (e.g., root, ubuntu): " SSH_USER

# Determine the current user's home directory for the credentials file
CURRENT_USER=$(whoami)
USER_HOME=$HOME

echo "----------------------------------------"
echo "Installing cloudflared"
echo "----------------------------------------"
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

echo "----------------------------------------"
echo "Login with account"
echo "----------------------------------------"
echo "Please click the link generated below to authorize your account in the browser."
cloudflared tunnel login

echo "----------------------------------------"
echo "Creating tunnel '$TUNNEL_NAME'"
echo "----------------------------------------"
cloudflared tunnel create $TUNNEL_NAME

# Automatically fetch the newly created Tunnel ID
TUNNEL_ID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')

if [ -z "$TUNNEL_ID" ]; then
    echo "Error: Could not retrieve Tunnel ID. Exiting."
    exit 1
fi
echo "Retrieved Tunnel ID: $TUNNEL_ID"

echo "----------------------------------------"
echo "Creating config file to redirect"
echo "----------------------------------------"
sudo mkdir -p /etc/cloudflared

# Generating the YAML config dynamically 
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID
credentials-file: $USER_HOME/.cloudflared/$TUNNEL_ID.json
ingress:
  - hostname: $HOST_NAME
    service: ssh://localhost:22
  - service: http_status:404
EOF

echo "----------------------------------------"
echo "Creating DNS Route"
echo "----------------------------------------"
cloudflared tunnel route dns $TUNNEL_NAME $HOST_NAME

echo "----------------------------------------"
echo "Service install & start"
echo "----------------------------------------"
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

echo "Checking service status..."
sudo systemctl status cloudflared --no-pager

echo "=================================================================="
echo "✅ SETUP COMPLETE!"
echo "=================================================================="
echo "To connect to this server from your local machine, ensure you have"
echo "cloudflared installed locally, then run the following command:"
echo ""
echo "ssh -o ProxyCommand=\"cloudflared access ssh --hostname $HOST_NAME\" $SSH_USER@$HOST_NAME"
echo ""
echo "=================================================================="

echo "Displaying real-time logs. Press Ctrl+C to exit."
journalctl -u cloudflared -f