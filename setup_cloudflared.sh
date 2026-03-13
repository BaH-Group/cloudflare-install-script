#!/bin/bash

echo "------------------------------------------------"
echo "Cloudflared Auto-Installer with SSH Check"
echo "------------------------------------------------"

# 1. Verify Admin Access
sudo -v || { echo "Admin access is required. Exiting."; exit 1; }

# 2. Gather Variables Interactively
read -p "Enter Tunnel Name (e.g., my-tunnel): " TUNNEL_NAME
read -p "Enter Full Hostname (e.g., ssh10.medikai.uz): " HOST_NAME
read -p "Enter SSH User on server (e.g., pi): " SSH_USER
read -p "Enter a Nickname for local SSH config (e.g., trash): " NICKNAME

# 3. Check and Install OpenSSH Server
echo "------------------------------------------------"
echo "Checking OpenSSH Server status..."
echo "------------------------------------------------"
if ! command -v sshd > /dev/null 2>&1; then
    echo "OpenSSH server is not installed. Installing now..."
    sudo apt update
    sudo apt install -y openssh-server
else
    echo "OpenSSH server is already installed."
fi

# Ensure the SSH service is running so the tunnel has something to connect to
sudo systemctl start ssh || sudo systemctl start sshd
sudo systemctl enable ssh || sudo systemctl enable sshd

# 4. Detect Architecture and Install Cloudflared
echo "------------------------------------------------"
echo "Installing Cloudflared"
echo "------------------------------------------------"
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    DEB_FILE="cloudflared-linux-arm64.deb"
else
    DEB_FILE="cloudflared-linux-amd64.deb"
fi

echo "Detected architecture: $ARCH. Downloading $DEB_FILE..."
rm -f "$DEB_FILE"
wget -q --show-progress "https://github.com/cloudflare/cloudflared/releases/latest/download/$DEB_FILE" [cite: 6, 7]

sudo dpkg -i "$DEB_FILE" [cite: 8]

# 5. Tunnel Authentication and Creation
echo "------------------------------------------------"
echo "Authenticating and Creating Tunnel"
echo "------------------------------------------------"
echo "Please follow the link below to login:"
cloudflared tunnel login [cite: 9, 10]

echo "Creating tunnel..."
cloudflared tunnel create "$TUNNEL_NAME" [cite: 11, 12]

# Get the Tunnel ID automatically
TUNNEL_ID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')
if [ -z "$TUNNEL_ID" ]; then
    echo "Failed to get Tunnel ID. Exiting."
    exit 1
fi

# 6. Create Configuration
echo "------------------------------------------------"
echo "Creating routing configuration..."
echo "------------------------------------------------"
sudo mkdir -p /etc/cloudflared [cite: 13, 14]
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $TUNNEL_ID [cite: 16, 17]
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json [cite: 18]
ingress: [cite: 19]
  - hostname: $HOST_NAME [cite: 20]
    service: ssh://localhost:22 [cite: 21]
  - service: http_status:404 [cite: 22]
EOF

# 7. Route DNS and Start Service
echo "Routing DNS..."
cloudflared tunnel route dns "$TUNNEL_NAME" "$HOST_NAME" [cite: 23, 24]

echo "Installing and starting service..."
sudo cloudflared service install [cite: 27, 28]
sudo systemctl start cloudflared [cite: 29]
sudo systemctl enable cloudflared [cite: 30]

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

# 8. Show Status and Logs
sudo systemctl status cloudflared --no-pager [cite: 31]
echo "Showing live logs (Press Ctrl+C to exit):"
journalctl -u cloudflared -f [cite: 32, 33]
