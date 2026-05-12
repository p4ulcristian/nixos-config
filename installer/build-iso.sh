#!/bin/bash
set -e

ISO_URL="https://releases.ubuntu.com/resolute/ubuntu-26.04-live-server-amd64.iso"
ISO_NAME="ubuntu-26.04-live-server-amd64.iso"
OUTPUT="iris-ubuntu-26.04-autoinstall.iso"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "IRIS Ubuntu Autoinstall ISO Builder"
echo "===================================="

# Download if needed
if [ ! -f "$ISO_NAME" ]; then
    echo "Downloading Ubuntu 26.04..."
    curl -L -O "$ISO_URL"
fi

# Build
echo "Building autoinstall ISO..."
xorriso -indev "$ISO_NAME" \
        -outdev "$OUTPUT" \
        -map "$SCRIPT_DIR/autoinstall" /autoinstall \
        -map "$SCRIPT_DIR/boot/grub/grub.cfg" /boot/grub/grub.cfg \
        -boot_image any replay

echo ""
echo "Done! Output: $OUTPUT"
echo "Flash with: sudo dd if=$OUTPUT of=/dev/sdX bs=4M status=progress"
