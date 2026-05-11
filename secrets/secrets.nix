# Agenix secrets configuration
# This file defines which keys can decrypt which secrets

let
  # User public keys (age or SSH)
  # Generate with: age-keygen -o ~/.config/agenix/key.txt
  # Get public key: age-keygen -y ~/.config/agenix/key.txt
  paul = "age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

  # Or use SSH public key directly
  # paul-ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";

  # System keys (generated during install)
  # Get from: ssh-keyscan localhost or /etc/ssh/ssh_host_ed25519_key.pub
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";

  # All users and systems that should access all secrets
  allKeys = [ paul server ];

in {
  # Cloudflared tunnel credentials
  # Create with: cloudflared tunnel create my-tunnel
  # Then: agenix -e cloudflared-credentials.age
  "cloudflared-credentials.age".publicKeys = allKeys;

  # GitHub token for gh CLI
  # Generate at: github.com/settings/tokens
  "gh-token.age".publicKeys = allKeys;

  # Anthropic API key for Claude
  "anthropic-api-key.age".publicKeys = allKeys;

  # Railway API token
  "railway-token.age".publicKeys = allKeys;

  # SSH private key for autossh tunnel
  "tunnel-ssh-key.age".publicKeys = allKeys;

  # General secrets file (sourced in shell)
  "shell-secrets.age".publicKeys = allKeys;
}
