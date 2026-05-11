# NixOS Preconfigured Server

Declarative NixOS configuration with Claude, Railway, GitHub CLI, Cloudflared, and AutoSSH preconfigured.

## Quick Start

### 1. Build the ISO

```bash
# On any machine with Nix installed
cd nixos-config

# Build bootable ISO
nix build .#nixosConfigurations.iso.config.system.build.isoImage

# ISO will be at: ./result/iso/nixos-preconfigured.iso
```

### 2. Write to USB

```bash
# Find your USB device
lsblk

# Write ISO (replace sdX with your device)
sudo dd if=./result/iso/nixos-preconfigured.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. Boot and Install

1. Boot from USB
2. Run: `sudo /etc/install-nixos.sh`
3. Follow the prompts
4. Reboot

## Setting Up Secrets

After installation, set up encrypted secrets using agenix:

### Generate age key

```bash
# On your new system
mkdir -p ~/.config/agenix
age-keygen -o ~/.config/agenix/key.txt

# Get the public key (add to secrets/secrets.nix)
age-keygen -y ~/.config/agenix/key.txt
```

### Add system SSH key to secrets.nix

```bash
# Get system public key
cat /etc/ssh/ssh_host_ed25519_key.pub
# Add to secrets/secrets.nix
```

### Create/edit secrets

```bash
# Install agenix CLI
nix shell github:ryantm/agenix

# Create secrets (will open $EDITOR)
cd /etc/nixos/secrets
agenix -e gh-token.age
agenix -e anthropic-api-key.age
agenix -e cloudflared-credentials.age
# etc.
```

### Secret file formats

**gh-token.age** (GitHub CLI):
```yaml
github.com:
  user: yourusername
  oauth_token: ghp_xxxxxxxxxxxx
  git_protocol: ssh
```

**anthropic-api-key.age**:
```
sk-ant-api03-xxxxxxxxxxxx
```

**shell-secrets.age** (environment variables):
```bash
export ANTHROPIC_API_KEY="sk-ant-api03-xxxx"
export RAILWAY_TOKEN="xxxx"
export CLOUDFLARE_API_TOKEN="xxxx"
```

**cloudflared-credentials.age**:
```json
{
  "AccountTag": "xxxxx",
  "TunnelID": "xxxxx",
  "TunnelSecret": "xxxxx"
}
```

### Rebuild with secrets

```bash
sudo nixos-rebuild switch
```

## Configuration Structure

```
nixos-config/
├── flake.nix                 # Main entry point
├── flake.lock                # Pinned dependencies
├── iso.nix                   # Bootable ISO configuration
├── hosts/
│   └── server/
│       ├── configuration.nix # Main system config
│       └── hardware-configuration.nix
├── modules/
│   ├── packages.nix          # claude, railway, gh, etc.
│   ├── services.nix          # cloudflared, autossh
│   ├── secrets.nix           # agenix secret definitions
│   └── users.nix             # user accounts, home-manager
├── overlays/
│   ├── claude.nix            # claude-code package
│   └── railway.nix           # railway CLI package
└── secrets/
    ├── secrets.nix           # agenix public keys
    └── *.age                  # encrypted secrets
```

## Common Operations

### Update system

```bash
# Update flake inputs
nix flake update

# Rebuild
sudo nixos-rebuild switch --flake /etc/nixos#server
```

### Rollback

```bash
# Immediate rollback
sudo nixos-rebuild switch --rollback

# Or select from boot menu
```

### Add new packages

Edit `modules/packages.nix`:
```nix
environment.systemPackages = with pkgs; [
  # ... existing
  newpackage
];
```

Then: `sudo nixos-rebuild switch`

### Sync config to git

```bash
cd /etc/nixos
git add -A
git commit -m "Update config"
git push
```

## Cloudflared Setup

1. Create tunnel:
```bash
cloudflared tunnel login
cloudflared tunnel create my-tunnel
```

2. Copy credentials to secrets:
```bash
cp ~/.cloudflared/*.json ~/tunnel-creds.json
agenix -e cloudflared-credentials.age  # paste contents
```

3. Create config (encrypt with agenix):
```yaml
tunnel: <tunnel-id>
credentials-file: /etc/cloudflared/credentials.json
ingress:
  - hostname: app.example.com
    service: http://localhost:3000
  - service: http_status:404
```

4. Update DNS:
```bash
cloudflared tunnel route dns my-tunnel app.example.com
```

## Troubleshooting

### Rebuild fails
```bash
# Check error details
sudo nixos-rebuild switch --show-trace

# Try building without switching
nix build .#nixosConfigurations.server.config.system.build.toplevel
```

### Secret not decrypting
```bash
# Verify age key exists
ls -la ~/.config/agenix/key.txt
ls -la /etc/ssh/ssh_host_ed25519_key

# Test decryption manually
age -d -i ~/.config/agenix/key.txt secrets/test.age
```

### Service not starting
```bash
systemctl status cloudflared-tunnel
journalctl -u cloudflared-tunnel -f
```
