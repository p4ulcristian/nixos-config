{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # ISO settings
  isoImage.isoName = lib.mkForce "nixos-autoinstall.iso";
  isoImage.volumeID = lib.mkForce "NIXOS_AUTO";

  # Include our config on the ISO
  isoImage.contents = [
    {
      source = ./.;
      target = "/nixos-config";
    }
  ];

  # Auto-login as root
  services.getty.autologinUser = lib.mkForce "root";

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Network
  networking.networkmanager.enable = true;

  # Packages needed for install
  environment.systemPackages = with pkgs; [
    git parted dosfstools e2fsprogs
  ];

  # Auto-install script that runs on boot
  systemd.services.autoinstall = {
    description = "Automatic NixOS Installation";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };

    script = ''
      #!/bin/bash
      set -euo pipefail

      echo ""
      echo "=========================================="
      echo "  NixOS Auto-Installer"
      echo "=========================================="
      echo ""

      # Find the target disk (first non-USB, non-CD disk)
      # For VM testing, this will be /dev/sda or /dev/vda
      DISK=""
      for d in /dev/vda /dev/sda /dev/nvme0n1; do
        if [ -b "$d" ]; then
          # Skip if it's the live USB/CD
          if ! mount | grep -q "$d"; then
            DISK="$d"
            break
          fi
        fi
      done

      if [ -z "$DISK" ]; then
        echo "ERROR: No suitable disk found for installation!"
        echo "Available block devices:"
        lsblk
        echo ""
        echo "Dropping to shell. Run manually:"
        echo "  /run/current-system/sw/bin/manual-install"
        exit 1
      fi

      echo "Target disk: $DISK"
      echo ""

      # Determine partition naming
      if [[ "$DISK" == *"nvme"* ]]; then
        PART1="''${DISK}p1"
        PART2="''${DISK}p2"
      else
        PART1="''${DISK}1"
        PART2="''${DISK}2"
      fi

      echo "Partitioning $DISK..."
      ${pkgs.parted}/bin/parted -s "$DISK" -- mklabel gpt
      ${pkgs.parted}/bin/parted -s "$DISK" -- mkpart ESP fat32 1MiB 512MiB
      ${pkgs.parted}/bin/parted -s "$DISK" -- mkpart primary 512MiB 100%
      ${pkgs.parted}/bin/parted -s "$DISK" -- set 1 esp on

      sleep 2

      echo "Formatting..."
      ${pkgs.dosfstools}/bin/mkfs.fat -F 32 -n boot "$PART1"
      ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L nixos "$PART2"

      echo "Mounting..."
      mount "$PART2" /mnt
      mkdir -p /mnt/boot
      mount "$PART1" /mnt/boot

      echo "Copying configuration..."
      mkdir -p /mnt/etc
      cp -r /nixos-config /mnt/etc/nixos

      echo "Generating hardware configuration..."
      nixos-generate-config --root /mnt
      cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/server/hardware-configuration.nix

      echo "Installing NixOS (this takes a while)..."
      nixos-install --flake /mnt/etc/nixos#server --no-root-passwd

      echo ""
      echo "=========================================="
      echo "  Installation Complete!"
      echo "=========================================="
      echo ""
      echo "Setting passwords..."

      # Set a default password (change after first boot!)
      echo "root:nixos" | chpasswd -R /mnt
      echo "paul:nixos" | chpasswd -R /mnt 2>/dev/null || true

      echo ""
      echo "Default password for root and paul: nixos"
      echo "CHANGE THIS AFTER FIRST BOOT!"
      echo ""
      echo "Rebooting in 10 seconds..."
      echo "(Remove installation media)"
      sleep 10
      reboot
    '';
  };

  # Manual install script as fallback
  environment.etc."manual-install.sh" = {
    mode = "0755";
    text = ''
      #!/bin/bash
      echo "Manual installation mode"
      echo "Available disks:"
      lsblk -d -o NAME,SIZE,MODEL
      echo ""
      read -p "Enter disk (e.g., sda): " DISK

      # Same install logic but interactive
      systemctl start autoinstall
    '';
  };
}
