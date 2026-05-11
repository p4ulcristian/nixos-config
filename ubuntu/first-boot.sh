#!/bin/bash
set -euo pipefail

# IRIS First Boot Setup
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

         F I R S T   B O O T   S E T U P

ASCIIART

echo ""

# Source Nix
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Wait for network
printf "  ⠿ Waiting for network"
for i in {1..30}; do
  if ping -c1 -W1 github.com &>/dev/null; then
    printf "\r  ✓ Network ready!              \n"
    break
  fi
  printf "."
  sleep 1
done

# Update config from GitHub
printf "  ⠿ Updating config..."
cd ~/.config/nixos
git pull --quiet 2>/dev/null || true
printf "\r  ✓ Config updated              \n"

# Run home-manager
printf "  ⠿ Installing home-manager...\n"
nix run home-manager -- switch --flake ~/.config/nixos#iris 2>&1 | while IFS= read -r line; do
  if [[ "$line" == *"copying"* ]] || [[ "$line" == *"building"* ]]; then
    pkg=$(echo "$line" | grep -oP '/nix/store/\S+' | head -1 | sed 's|.*/||' | cut -c1-50)
    if [ -n "$pkg" ]; then
      printf "\r    ⠿ %-50s" "$pkg"
    fi
  fi
done
printf "\r  ✓ Home-manager installed!              \n"

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║                                      ║"
echo "  ║      I R I S   I S   R E A D Y       ║"
echo "  ║                                      ║"
echo "  ║   SSH: ssh iris@$(hostname -I | awk '{print $1}')   ║"
echo "  ║                                      ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# Disable this service after first run
sudo systemctl disable iris-setup.service
