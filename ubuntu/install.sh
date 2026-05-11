#!/bin/bash
set -euo pipefail

# IRIS Setup Script - Run this after Ubuntu install
clear
cat << "ASCIIART"

                      ▄▄▄███████▄▄▄
                  ▄██████████████████▄
               ▄███▀▀          ▀▀███▄
             ▄██▀    ▄▄██████▄▄    ▀██▄
            ██▀    ▄██▀▀    ▀▀██▄    ▀██
           ██    ▄██   ▄████▄   ██▄    ██
          ██    ██   ▄██████▄   ██    ██
          ██    ██   ██████████   ██    ██
          ██    ██   ▀██████▀   ██    ██
           ██    ▀██   ▀████▀   ██▀    ██
            ██▄    ▀██▄▄    ▄▄██▀    ▄██
             ▀██▄    ▀▀██████▀▀    ▄██▀
               ▀███▄▄          ▄▄███▀
                  ▀██████████████▀
                      ▀▀▀███▀▀▀


               ██╗██████╗ ██╗███████╗
               ██║██╔══██╗██║██╔════╝
               ██║██████╔╝██║███████╗
               ██║██╔══██╗██║╚════██║
               ██║██║  ██║██║███████║
               ╚═╝╚═╝  ╚═╝╚═╝╚══════╝

              S E T U P   S C R I P T

ASCIIART

echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "  Please run as normal user (not root)"
  exit 1
fi

# Install dependencies
printf "  ⠿ Installing dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq git curl zsh > /dev/null 2>&1
printf "\r  ✓ Dependencies installed     \n"

# Install Nix
if ! command -v nix &> /dev/null; then
  printf "  ⠿ Installing Nix..."
  curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes > /dev/null 2>&1
  printf "\r  ✓ Nix installed              \n"

  # Source Nix
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Clone config
printf "  ⠿ Cloning config..."
if [ -d ~/.config/nixos ]; then
  cd ~/.config/nixos && git pull --quiet
else
  git clone --quiet https://github.com/p4ulcristian/nixos-config ~/.config/nixos
fi
printf "\r  ✓ Config ready               \n"

# Run home-manager
printf "  ⠿ Running home-manager...\n"
nix run home-manager -- switch --flake ~/.config/nixos#iris 2>&1 | while IFS= read -r line; do
  if [[ "$line" == *"copying"* ]] || [[ "$line" == *"building"* ]]; then
    pkg=$(echo "$line" | grep -oP '/nix/store/\S+' | head -1 | sed 's|.*/||' | cut -c1-45)
    if [ -n "$pkg" ]; then
      printf "\r    ⠿ %-50s" "$pkg"
    fi
  fi
done
printf "\r  ✓ Home-manager complete!               \n"

# Set zsh as default shell
printf "  ⠿ Setting zsh as default shell..."
sudo chsh -s $(which zsh) $USER
printf "\r  ✓ Shell configured           \n"

# Add SSH keys
printf "  ⠿ Configuring SSH..."
mkdir -p ~/.ssh
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG5858m5yHShPBI6j6W0UtKZcDtNXM3MTwEmb5B9Gv7d
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBnfnRzOc3sOQTnxWO3ticIlORvQeexu/Yudhfd+I0HI
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOlBKLnsb1oPzscTGGB7QPPNIa8iMYLV2TRjMZUSKXx
EOF
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
printf "\r  ✓ SSH configured             \n"

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║                                      ║"
echo "  ║      I R I S   I S   R E A D Y       ║"
echo "  ║                                      ║"
echo "  ║   Log out and back in for zsh       ║"
echo "  ║   Or run: exec zsh                  ║"
echo "  ║                                      ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
