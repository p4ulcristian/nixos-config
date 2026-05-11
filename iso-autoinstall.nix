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

  # Faster squashfs compression (zstd instead of xz)
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  # Auto-login as root
  services.getty.autologinUser = lib.mkForce "root";

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Minimal network (no WiFi, no NetworkManager bloat)
  networking.wireless.enable = lib.mkForce false;
  networking.networkmanager.enable = lib.mkForce false;
  networking.dhcpcd.enable = true;

  # Include network firmware (needed for most NICs)
  hardware.enableRedistributableFirmware = lib.mkForce true;

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

ASCIIART
      echo ""

      # Wait for network
      printf "  ⠿ Waiting for network"
      for i in {1..60}; do
        if ping -c1 -W1 github.com &>/dev/null; then
          printf "\r  ✓ Network ready!              \n"
          break
        fi
        printf "."
        sleep 1
      done

      # Show available disks (silent)
      ${pkgs.util-linux}/bin/lsblk -d -o NAME,SIZE,MODEL > /tmp/disks.txt

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
        echo "  ✗ No suitable disk found!"
        cat /tmp/disks.txt
        exit 1
      fi

      printf "  ✓ Target: %s\n" "$DISK"

      # Partition naming
      if [[ "$DISK" == *"nvme"* ]]; then
        PART1="''${DISK}p1"
        PART2="''${DISK}p2"
      else
        PART1="''${DISK}1"
        PART2="''${DISK}2"
      fi

      printf "  ⠿ Partitioning..."
      ${pkgs.parted}/bin/parted -s "$DISK" -- mklabel gpt >/dev/null 2>&1
      ${pkgs.parted}/bin/parted -s "$DISK" -- mkpart ESP fat32 1MiB 512MiB >/dev/null 2>&1
      ${pkgs.parted}/bin/parted -s "$DISK" -- mkpart primary 512MiB 100% >/dev/null 2>&1
      ${pkgs.parted}/bin/parted -s "$DISK" -- set 1 esp on >/dev/null 2>&1
      sleep 2
      printf "\r  ✓ Partitioned            \n"

      printf "  ⠿ Formatting..."
      ${pkgs.dosfstools}/bin/mkfs.fat -F 32 -n boot "$PART1" >/dev/null 2>&1
      ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L nixos "$PART2" >/dev/null 2>&1
      printf "\r  ✓ Formatted              \n"

      mount "$PART2" /mnt
      mkdir -p /mnt/boot
      mount "$PART1" /mnt/boot

      printf "  ⠿ Cloning config..."
      ${pkgs.git}/bin/git clone --quiet https://github.com/p4ulcristian/nixos-config /mnt/etc/nixos >/dev/null 2>&1
      printf "\r  ✓ Config cloned          \n"

      printf "  ⠿ Detecting hardware..."
      nixos-generate-config --root /mnt >/dev/null 2>&1
      cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/server/hardware-configuration.nix
      printf "\r  ✓ Hardware detected      \n"

      echo ""
      echo "  Installing NixOS..."
      echo ""

      # Run install with progress display
      nixos-install --flake /mnt/etc/nixos#server --no-root-passwd 2>&1 | while IFS= read -r line; do
        # Show copying/building lines with package names
        if [[ "$line" == *"copying"* ]] || [[ "$line" == *"building"* ]]; then
          pkg=$(echo "$line" | grep -oP '/nix/store/\S+' | head -1 | sed 's|.*/||' | cut -c1-50)
          if [ -n "$pkg" ]; then
            printf "\r  ⠿ %-55s" "$pkg"
          fi
        fi
      done
      echo ""
      echo ""
      echo "  ✓ Installation complete!"

      printf "  ⠿ Configuring user..."
      echo "root:nixos" | chpasswd -R /mnt 2>/dev/null
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
      printf "\r  ✓ User configured        \n"

      echo ""
      echo ""
      echo "  ╔══════════════════════════════════════╗"
      echo "  ║                                      ║"
      echo "  ║      I R I S   I S   R E A D Y       ║"
      echo "  ║                                      ║"
      echo "  ║   User: iris    Password: nixos     ║"
      echo "  ║                                      ║"
      echo "  ╚══════════════════════════════════════╝"
      echo ""
      echo "  Rebooting in 10 seconds..."
      echo "  (Remove USB drive)"
      sleep 10
      reboot
    '';
  };
}
