{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # ISO settings
  isoImage.isoName = lib.mkForce "nixos-autoinstall.iso";
  isoImage.volumeID = lib.mkForce "NIXOS_AUTO";

  # Instant boot (no menu delay)
  boot.loader.timeout = lib.mkForce 0;

  # Auto-login as root
  services.getty.autologinUser = lib.mkForce "root";

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Minimal network (no WiFi, no NetworkManager bloat)
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager.enable = lib.mkForce false;
  networking.dhcpcd.enable = true;

  # No firmware bloat (no WiFi, no Bluetooth, no GPU firmware)
  hardware.enableRedistributableFirmware = lib.mkForce false;

  # No sound
  sound.enable = false;

  # Wait for network before auto-install
  systemd.services.autoinstall.wants = [ "network-online.target" ];
  systemd.services.autoinstall.after = [ "network-online.target" ];

  # Packages needed for install
  environment.systemPackages = with pkgs; [
    git parted dosfstools e2fsprogs util-linux
  ];

  # Auto-install service
  systemd.services.autoinstall = {
    description = "Automatic NixOS Installation";
    wantedBy = [ "multi-user.target" ];

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

      # Wait for network (shorter timeout, faster checks)
      echo "Waiting for network..."
      for i in {1..60}; do
        if ping -c1 -W1 github.com &>/dev/null; then
          echo "Network ready!"
          break
        fi
        echo -n "."
        sleep 1
      done
      echo ""

      # Show available disks
      echo "Available disks:"
      lsblk -d -o NAME,SIZE,MODEL

      # Find target disk - prefer NVMe (internal) over sda (likely USB boot)
      DISK=""
      for d in /dev/nvme0n1 /dev/nvme1n1 /dev/sdb /dev/vda; do
        if [ -b "$d" ]; then
          DISK="$d"
          break
        fi
      done

      # Fallback to sda only if nothing else found
      if [ -z "$DISK" ] && [ -b "/dev/sda" ]; then
        echo "WARNING: Only /dev/sda found - make sure this is not your boot USB!"
        sleep 5
        DISK="/dev/sda"
      fi

      if [ -z "$DISK" ]; then
        echo "ERROR: No suitable disk found!"
        lsblk
        exit 1
      fi

      echo "Target disk: $DISK"

      # Partition naming
      if [[ "$DISK" == *"nvme"* ]]; then
        PART1="''${DISK}p1"
        PART2="''${DISK}p2"
      else
        PART1="''${DISK}1"
        PART2="''${DISK}2"
      fi

      echo "Partitioning..."
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

      echo "Cloning config from GitHub..."
      ${pkgs.git}/bin/git clone https://github.com/p4ulcristian/nixos-config /mnt/etc/nixos

      echo "Generating hardware config..."
      nixos-generate-config --root /mnt
      cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/server/hardware-configuration.nix

      echo "Installing NixOS..."
      nixos-install --flake /mnt/etc/nixos#server --no-root-passwd

      echo ""
      echo "=========================================="
      echo "  Setting passwords..."
      echo "=========================================="
      echo "root:nixos" | chpasswd -R /mnt
      echo "iris:nixos" | chpasswd -R /mnt 2>/dev/null || true

      # Create Claude config dir with bypass permissions
      mkdir -p /mnt/home/iris/.config/claude
      cat > /mnt/home/iris/.config/claude/settings.json << 'CLAUDE_SETTINGS'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)",
      "WebFetch(*)"
    ],
    "deny": []
  }
}
CLAUDE_SETTINGS
      chown -R 1000:100 /mnt/home/iris/.config

      echo ""
      echo "=========================================="
      echo "  INSTALLATION COMPLETE!"
      echo "=========================================="
      echo ""
      echo "Credentials:"
      echo "  User: iris"
      echo "  Password: nixos"
      echo ""
      echo "Claude permissions: ALL BYPASSED"
      echo ""
      echo "Rebooting in 10 seconds..."
      echo "(Remove USB drive)"
      sleep 10
      reboot
    '';
  };
}
