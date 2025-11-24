#!/bin/bash
# Fix SMSL DAC (and other XMOS-based USB DACs) popping noise on Linux
# This script addresses the "pop" sound that occurs when audio starts after silence
#
# What it does:
# 1. Disables USB autosuspend for SMSL devices
# 2. Disables ALSA autoclock to prevent sample rate switching pops
# 3. Adds delayed registration for proper XMOS device initialization
# 4. Creates a keepalive service to prevent PipeWire pipeline suspension
#
# Tested on: Arch Linux with PipeWire
# Device: SMSL RAW MDA 1 (USB ID 152a:85dd)
# Should work with other SMSL/XMOS devices as well

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "SMSL DAC Popping Fix for Linux"
echo "======================================"
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run this script as root${NC}"
    echo "The script will prompt for sudo when needed"
    exit 1
fi

# Check for required commands
if ! command -v paplay &> /dev/null; then
    echo -e "${YELLOW}Warning: paplay not found. Install pulseaudio-utils or pipewire-pulse${NC}"
fi

# Detect SMSL device
echo "[1/5] Detecting SMSL USB Audio devices..."
SMSL_DEVICE=$(find /sys/bus/usb/devices -name manufacturer -exec grep -l "SMSL" {} \; 2>/dev/null | head -1)

if [ -n "$SMSL_DEVICE" ]; then
    DEVICE_PATH=$(dirname "$SMSL_DEVICE")
    VENDOR_ID=$(cat "$DEVICE_PATH/idVendor")
    PRODUCT_ID=$(cat "$DEVICE_PATH/idProduct")
    PRODUCT_NAME=$(cat "$DEVICE_PATH/product" 2>/dev/null || echo "Unknown")
    echo -e "${GREEN}✓ Found SMSL device: $PRODUCT_NAME${NC}"
    echo "  Vendor ID: $VENDOR_ID"
    echo "  Product ID: $PRODUCT_ID"
else
    echo -e "${YELLOW}⚠ No SMSL device detected. Continuing anyway...${NC}"
    echo "  The script will create generic configs that should work when device is connected."
    VENDOR_ID="152a"
    PRODUCT_ID="85dd"
fi
echo

# Create udev rule to disable USB autosuspend
echo "[2/5] Creating udev rule to disable USB autosuspend..."
UDEV_RULE="/tmp/50-smsl-dac-no-autosuspend.rules"
cat > "$UDEV_RULE" << 'EOF'
# Disable USB autosuspend for SMSL DACs to prevent popping noises
# Applies to all SMSL devices (vendor ID 152a)
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="152a", TEST=="power/control", ATTR{power/control}="on"
EOF

sudo cp "$UDEV_RULE" /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
echo -e "${GREEN}✓ Udev rule installed${NC}"
echo

# Create ALSA module configuration
echo "[3/5] Creating ALSA USB audio module configuration..."
ALSA_CONF="/tmp/alsa-smsl-fix.conf"
cat > "$ALSA_CONF" << 'EOF'
# Fix SMSL/XMOS DAC popping noise
# - autoclock=0: Disables automatic clock switching between sample rates (main fix)
# - delayed_register: Adds initialization delay for proper XMOS device setup
options snd_usb_audio autoclock=0 vid=0x152a pid=0x85dd delayed_register=1s
EOF

sudo cp "$ALSA_CONF" /etc/modprobe.d/alsa-smsl-fix.conf
echo -e "${GREEN}✓ ALSA configuration installed${NC}"
echo "  Note: Requires reboot or module reload to take effect"
echo

# Create systemd user service for keepalive
echo "[4/5] Creating PipeWire keepalive service..."
mkdir -p ~/.config/systemd/user

KEEPALIVE_SERVICE="$HOME/.config/systemd/user/smsl-keepalive.service"
cat > "$KEEPALIVE_SERVICE" << 'EOF'
[Unit]
Description=SMSL DAC Keepalive - Prevent popping by keeping audio pipeline active
Documentation=https://www.audiosciencereview.com/forum/index.php?threads/xmos-driver-settings-for-no-cutoff-delay.25838/
After=pipewire.service pipewire-pulse.service

[Service]
Type=simple
# Play silence at volume 0 to keep the audio pipeline active
# This prevents PipeWire from suspending the device, which causes popping
ExecStart=/usr/bin/paplay /dev/zero --raw --channels=2 --rate=48000 --format=s16le --volume=0
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable smsl-keepalive.service
systemctl --user start smsl-keepalive.service
echo -e "${GREEN}✓ Keepalive service installed and started${NC}"
echo

# Summary
echo "[5/5] Installation complete!"
echo
echo -e "${GREEN}======================================"
echo "Summary of changes:"
echo "======================================${NC}"
echo "1. USB autosuspend disabled for SMSL devices"
echo "   → /etc/udev/rules.d/50-smsl-dac-no-autosuspend.rules"
echo
echo "2. ALSA autoclock disabled (prevents sample rate switching pops)"
echo "   → /etc/modprobe.d/alsa-smsl-fix.conf"
echo
echo "3. PipeWire keepalive service enabled (prevents pipeline suspension pops)"
echo "   → ~/.config/systemd/user/smsl-keepalive.service"
echo
echo -e "${YELLOW}⚠ Important: You must REBOOT for all changes to take effect${NC}"
echo
echo "After reboot, the popping should be eliminated when audio starts."
echo
echo "To check service status:"
echo "  systemctl --user status smsl-keepalive.service"
echo
echo "To disable keepalive (if needed):"
echo "  systemctl --user stop smsl-keepalive.service"
echo "  systemctl --user disable smsl-keepalive.service"
echo
echo "Resource usage: ~5MB RAM, 0% CPU"
echo
echo -e "${GREEN}Enjoy your pop-free audio! 🎵${NC}"
