# IRIS Ubuntu Autoinstaller

Automated Ubuntu 26.04 installation with Nix + home-manager.

## USB Install (Recommended)

1. Download Ubuntu 26.04 server ISO
2. Build autoinstall ISO:
   ```bash
   # Extract ISO
   7z x ubuntu-26.04-live-server-amd64.iso -oiso_extract

   # Add autoinstall config
   cp -r autoinstall iso_extract/

   # Repack with xorriso
   xorriso -indev ubuntu-26.04-live-server-amd64.iso \
           -outdev iris-ubuntu-autoinstall.iso \
           -map autoinstall /autoinstall \
           -boot_image any replay
   ```
3. Flash to USB: `dd if=iris-ubuntu-autoinstall.iso of=/dev/sdX bs=4M`
4. Boot from USB

## PXE Install (Advanced)

1. Download netboot files from releases.ubuntu.com
2. Place kernel/initrd in `http/` directory
3. Run `./start.sh` (starts HTTP + DHCP/TFTP)
4. Network boot the server

## What Gets Installed

- Ubuntu 26.04 LTS
- User: `iris` with SSH keys
- First boot runs `iris-setup.service`:
  - Installs Nix
  - Clones this repo
  - Runs home-manager
