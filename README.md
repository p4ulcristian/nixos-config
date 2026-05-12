# iris-machine

Nix home-manager configuration for Ubuntu with Claude, GitHub CLI, Cloudflared, and more.

## Install on Fresh Ubuntu

```bash
# Install Nix
curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes

# Enable flakes
echo "experimental-features = nix-command flakes" | sudo tee /etc/nix/nix.conf

# Log out and back in, then:
git clone <this-repo> ~/iris-machine
NIXPKGS_ALLOW_UNFREE=1 nix run home-manager --impure -- switch --flake ~/iris-machine#iris --impure
```

## Usage

```bash
# Apply changes after editing config
home-manager switch --flake ~/iris-machine#iris --impure

# Update all packages
cd ~/iris-machine && nix flake update
home-manager switch --flake ~/iris-machine#iris --impure

# Rollback
home-manager generations
home-manager switch --rollback
```

## Secrets

Secrets are managed with SOPS + age. Edit `secrets/secrets.yaml`:

```bash
# Decrypt and edit (requires age key)
sops secrets/secrets.yaml
```

Then source them in your shell:
```bash
# ~/.secrets
export ANTHROPIC_API_KEY="sk-ant-..."
export GITHUB_TOKEN="ghp_..."
export CLOUDFLARE_API_TOKEN="..."
```

## Structure

```
iris-machine/
├── flake.nix           # Nix flake entry point
├── flake.lock          # Pinned dependencies
├── home/
│   └── default.nix     # Home-manager config (packages, shell, etc.)
└── secrets/
    └── secrets.yaml    # SOPS-encrypted secrets
```

## Included Tools

- git, gh, vim, curl, wget, htop, tmux, jq
- ripgrep, fd, fzf, bat, eza
- nodejs 20, 1password-cli
- cloudflared, autossh, mosh
- zsh with Oh My Zsh
