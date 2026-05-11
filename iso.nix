{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    ./modules/packages.nix
    # Don't import services.nix - services need secrets that aren't available yet
    # Don't import secrets.nix - secrets are set up after install
  ];

  # ============================================
  # ISO-specific configuration
  # ============================================

  # ISO label
  isoImage.isoName = lib.mkForce "nixos-preconfigured.iso";
  isoImage.volumeID = lib.mkForce "NIXOS_PRE";

  # Include the config repo on the ISO for easy install
  isoImage.contents = [
    {
      source = ./.;
      target = "/nixos-config";
    }
  ];

  # ============================================
  # Live environment configuration
  # ============================================

  # Allow unfree
  nixpkgs.config.allowUnfree = true;

  # Enable flakes in live environment
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Networking for live environment
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  # Auto-login for live ISO
  services.getty.autologinUser = lib.mkForce "nixos";

  # Give nixos user sudo
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "nixos";
  };
  security.sudo.wheelNeedsPassword = false;

  # ============================================
  # Pre-install packages
  # ============================================

  environment.systemPackages = with pkgs; [
    # Editors
    vim
    nano

    # Disk tools
    parted
    dosfstools
    e2fsprogs
    btrfs-progs

    # Network
    networkmanager
    curl
    wget
    git

    # Utilities
    tmux
    htop
    unzip

    # For secrets setup
    age
    # agenix  # Install via nix shell if needed

    # Our tools (for testing in live env)
    nodejs_20
    nodePackages.npm
    gh
    cloudflared
    autossh
  ];

  # ============================================
  # Install helper script
  # ============================================

  environment.etc."install-nixos.sh" = {
    mode = "0755";
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Colors
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      NC='\033[0m'

      echo -e "''${GREEN}========================================''${NC}"
      echo -e "''${GREEN}  NixOS Preconfigured Install Script    ''${NC}"
      echo -e "''${GREEN}========================================''${NC}"
      echo ""

      # Check if running as root
      if [ "$EUID" -ne 0 ]; then
        echo -e "''${RED}Please run as root: sudo /etc/install-nixos.sh''${NC}"
        exit 1
      fi

      # List disks
      echo -e "''${YELLOW}Available disks:''${NC}"
      lsblk -d -o NAME,SIZE,MODEL
      echo ""

      # Ask for target disk
      read -p "Enter target disk (e.g., sda, nvme0n1): " DISK
      DISK="/dev/$DISK"

      if [ ! -b "$DISK" ]; then
        echo -e "''${RED}Disk $DISK not found!''${NC}"
        exit 1
      fi

      echo -e "''${RED}WARNING: This will ERASE $DISK''${NC}"
      read -p "Type 'yes' to continue: " CONFIRM
      if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 1
      fi

      # Determine partition suffix (nvme uses p1, sda uses 1)
      if [[ "$DISK" == *"nvme"* ]]; then
        PART_PREFIX="''${DISK}p"
      else
        PART_PREFIX="$DISK"
      fi

      echo -e "''${GREEN}Partitioning $DISK...''${NC}"

      # Partition: GPT with EFI + root
      parted -s "$DISK" -- mklabel gpt
      parted -s "$DISK" -- mkpart ESP fat32 1MiB 512MiB
      parted -s "$DISK" -- mkpart primary 512MiB 100%
      parted -s "$DISK" -- set 1 esp on

      sleep 2  # Wait for kernel to recognize partitions

      echo -e "''${GREEN}Formatting...''${NC}"
      mkfs.fat -F 32 -n boot "''${PART_PREFIX}1"
      mkfs.ext4 -L nixos "''${PART_PREFIX}2"

      echo -e "''${GREEN}Mounting...''${NC}"
      mount "''${PART_PREFIX}2" /mnt
      mkdir -p /mnt/boot
      mount "''${PART_PREFIX}1" /mnt/boot

      echo -e "''${GREEN}Copying configuration...''${NC}"
      mkdir -p /mnt/etc
      cp -r /nixos-config /mnt/etc/nixos

      echo -e "''${GREEN}Generating hardware configuration...''${NC}"
      nixos-generate-config --root /mnt
      # Keep our config, just use the hardware-configuration
      cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/server/hardware-configuration.nix

      echo -e "''${GREEN}Installing NixOS...''${NC}"
      nixos-install --flake /mnt/etc/nixos#server --no-root-passwd

      echo -e "''${GREEN}========================================''${NC}"
      echo -e "''${GREEN}  Installation complete!                ''${NC}"
      echo -e "''${GREEN}========================================''${NC}"
      echo ""
      echo "Next steps:"
      echo "1. Set root password: nixos-enter --root /mnt -c 'passwd'"
      echo "2. Set user password: nixos-enter --root /mnt -c 'passwd paul'"
      echo "3. Set up secrets (see /mnt/etc/nixos/README.md)"
      echo "4. Reboot: reboot"
    '';
  };

  # ============================================
  # MOTD with instructions
  # ============================================

  environment.etc."motd".text = ''

    ╔═══════════════════════════════════════════════════════════════╗
    ║           NixOS Preconfigured Live Environment                ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║                                                               ║
    ║  To install NixOS with your preconfigured settings:           ║
    ║                                                               ║
    ║    sudo /etc/install-nixos.sh                                 ║
    ║                                                               ║
    ║  Your config is available at: /nixos-config                   ║
    ║                                                               ║
    ║  Tools available in this live environment:                    ║
    ║    - claude (via npx)                                         ║
    ║    - railway (via npx)                                        ║
    ║    - gh                                                       ║
    ║    - cloudflared                                              ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

  '';

}
