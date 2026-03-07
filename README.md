# Cloudflared Tunnel Setup Script

This project provides an interactive Bash script to install and configure a Cloudflare Tunnel (`cloudflared`) for SSH access.

Script: `setup_cloudflared.sh`

## What the script does

The script performs the following steps:

1. Verifies `sudo` access.
2. Prompts for:
   - Tunnel name (for example: `my-tunnel`)
   - Hostname to route (for example: `ssh.example.com`)
3. Downloads and installs `cloudflared` Debian package.
4. Starts Cloudflare authentication flow with `cloudflared tunnel login`.
5. Creates a tunnel.
6. Reads the tunnel ID from tunnel list.
7. Creates `/etc/cloudflared/config.yml` with SSH ingress:
   - `hostname: <your-hostname>`
   - `service: ssh://localhost:22`
8. Creates DNS route for the hostname.
9. Installs and enables `cloudflared` systemd service.
10. Shows service status and tails logs.

## Requirements

- Linux host with `systemd`
- Debian/Ubuntu-style package support (`dpkg`)
- `wget`, `sudo`, `awk`, `grep`
- Cloudflare account with access to the target domain
- Domain/subdomain already managed in Cloudflare
- OpenSSH server running locally on port `22` (if using SSH ingress as-is)

## Usage

```bash
chmod +x setup_cloudflared.sh
./setup_cloudflared.sh
```

During execution:

- Approve `sudo` prompt
- Complete browser login when `cloudflared tunnel login` prints the URL
- Provide tunnel name and hostname when prompted

## Generated configuration

The script writes:

- Credentials: `$HOME/.cloudflared/<TUNNEL_ID>.json`
- Config: `/etc/cloudflared/config.yml`

Config structure used:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /home/<user>/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: <HOST_NAME>
    service: ssh://localhost:22
  - service: http_status:404
```

## Connect over SSH through Cloudflare Access

From a client machine, use Cloudflare's access command in your SSH config or command line. Example:

```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname <HOST_NAME>" <user>@<HOST_NAME>
```

## Service management

Useful commands:

```bash
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -f
sudo systemctl restart cloudflared
```

## Notes and limitations

- The installer URL is for `cloudflared-linux-amd64.deb`.
- The script assumes SSH service at `localhost:22`.
- If `cloudflared tunnel list` parsing fails, tunnel ID detection may fail.
- The script is interactive and intended for manual execution.
