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

# Determine the current user's home directory for the credentials file
CURRENT_USER=$(whoami)
USER_HOME=$HOME

echo "----------------------------------------"
echo "Installing cloudflared"
echo "----------------------------------------"
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb [cite: 6, 7]
sudo dpkg -i cloudflared-linux-amd64.deb [cite: 8]

echo "----------------------------------------"
echo "Login with account"
echo "----------------------------------------"
echo "Please click the link generated below to authorize your account in the browser."
cloudflared tunnel login [cite: 9, 10]

echo "----------------------------------------"
echo "Creating tunnel '$TUNNEL_NAME'"
echo "----------------------------------------"
cloudflared tunnel create $TUNNEL_NAME [cite: 11, 12]

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
sudo mkdir -p /etc/cloudflared [cite: 13, 14]

# Generating the YAML config dynamically 
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID [cite: 16, 17]
credentials-file: $USER_HOME/.cloudflared/$TUNNEL_ID.json [cite: 18]
ingress: [cite: 19]
  - hostname: $HOST_NAME [cite: 20]
    service: ssh://localhost:22 [cite: 21]
  - service: http_status:404 [cite: 22]
EOF

echo "----------------------------------------"
echo "Creating DNS Route"
echo "----------------------------------------"
cloudflared tunnel route dns $TUNNEL_NAME $HOST_NAME [cite: 23, 24]

echo "----------------------------------------"
echo "Service install & start"
echo "----------------------------------------"
sudo cloudflared service install [cite: 27, 28]
sudo systemctl start cloudflared [cite: 29]
sudo systemctl enable cloudflared [cite: 30]

echo "Checking service status..."
sudo systemctl status cloudflared --no-pager [cite: 31]

echo "----------------------------------------"
echo "Testing Logs"
echo "----------------------------------------"
echo "Displaying real-time logs. Press Ctrl+C to exit."
journalctl -u cloudflared -f [cite: 32, 33]