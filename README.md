# Fix SMSL DAC Popping Noise on Linux

A comprehensive fix for the annoying "pop" or "click" sound that occurs when audio starts playing on SMSL and other XMOS-based USB DACs running Linux.

## The Problem

SMSL DACs (like the RAW MDA 1) and other XMOS-based USB audio devices often produce a popping/clicking sound when:
- Audio playback starts after silence
- Switching between tracks
- Pausing and resuming audio

This is the Linux equivalent of the Windows XMOS driver "Always On" streaming mode issue documented in [this AudioScienceReview thread](https://www.audiosciencereview.com/forum/index.php?threads/xmos-driver-settings-for-no-cutoff-delay.25838/).

## The Solution

The popping is caused by multiple power management systems:

1. **USB Autosuspend** - USB device enters low-power state when idle
2. **ALSA Autoclock** - Automatic sample rate switching causes clock changes
3. **PipeWire Pipeline Suspension** - Audio pipeline suspends when no audio is playing

This script addresses all three causes:

### 1. Disable USB Autosuspend
Creates a udev rule that keeps SMSL USB devices powered on at all times.

### 2. Disable ALSA Autoclock
Configures the `snd_usb_audio` kernel module to prevent automatic clock switching between sample rates.

### 3. PipeWire Keepalive Service
Runs a silent audio stream (at volume 0) to keep the PipeWire audio pipeline active, preventing device suspension.

## Installation

### Quick Install

```bash
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/smsl-linux-fix/main/fix-smsl-popping.sh
chmod +x fix-smsl-popping.sh
./fix-smsl-popping.sh
sudo reboot
```

### Manual Install

1. Download the script:
   ```bash
   wget https://raw.githubusercontent.com/YOUR_USERNAME/smsl-linux-fix/main/fix-smsl-popping.sh
   ```

2. Make it executable:
   ```bash
   chmod +x fix-smsl-popping.sh
   ```

3. Run the script:
   ```bash
   ./fix-smsl-popping.sh
   ```

4. Reboot your system:
   ```bash
   sudo reboot
   ```

## Compatibility

### Tested On
- **Distribution:** Arch Linux
- **Audio Server:** PipeWire
- **Device:** SMSL RAW MDA 1 (USB ID: 152a:85dd)

### Should Work On
- Any Linux distribution using PipeWire or PulseAudio
- Any SMSL USB audio device (all use vendor ID 152a)
- Other XMOS-based USB DACs with similar issues

### Requirements
- systemd (for the keepalive service)
- PipeWire or PulseAudio (for `paplay` command)
- sudo access (for installing system files)

## What Gets Installed

The script creates three configuration files:

1. **`/etc/udev/rules.d/50-smsl-dac-no-autosuspend.rules`**
   - Disables USB autosuspend for all SMSL devices
   - Applied automatically when device is connected

2. **`/etc/modprobe.d/alsa-smsl-fix.conf`**
   - Configures ALSA USB audio module parameters
   - Takes effect on boot or module reload

3. **`~/.config/systemd/user/smsl-keepalive.service`**
   - Systemd user service that plays silence
   - Starts automatically on login

## Resource Usage

The keepalive service is extremely lightweight:
- **CPU:** 0% (effectively nothing)
- **Memory:** ~5MB RAM
- **Impact:** Negligible on any modern system

## Verification

After rebooting, verify the fix is working:

### Check USB power control:
```bash
cat /sys/bus/usb/devices/*/power/control | grep -v auto
```
Should show `on` for your SMSL device.

### Check ALSA autoclock:
```bash
cat /sys/module/snd_usb_audio/parameters/autoclock
```
Should show `N` (disabled).

### Check keepalive service:
```bash
systemctl --user status smsl-keepalive.service
```
Should show `active (running)`.

## Troubleshooting

### The popping is still there
1. Ensure you've rebooted after running the script
2. Check that all three components are active (see Verification above)
3. Try increasing the silence stream sample rate in the service file

### The keepalive service won't start
- Make sure `paplay` is installed: `sudo pacman -S pipewire-pulse` (Arch) or equivalent
- Check service logs: `journalctl --user -u smsl-keepalive.service`

### I want to disable the fix
```bash
# Stop and disable keepalive service
systemctl --user stop smsl-keepalive.service
systemctl --user disable smsl-keepalive.service

# Remove configuration files
sudo rm /etc/udev/rules.d/50-smsl-dac-no-autosuspend.rules
sudo rm /etc/modprobe.d/alsa-smsl-fix.conf
rm ~/.config/systemd/user/smsl-keepalive.service

# Reload and reboot
sudo udevadm control --reload-rules
sudo reboot
```

## Technical Details

### Why Does This Happen?

On Windows, the XMOS driver has a "USB streaming mode" setting that can be set to "Always On" to prevent the device from entering standby. On Linux, there's no equivalent driver control panel, so we need to configure multiple system components to achieve the same result.

### Alternative Solutions

If you don't want to use the keepalive service (which keeps audio pipeline active), you can try:

1. **Longer suspend timeout:** Configure PipeWire/WirePlumber to wait longer before suspending (doesn't eliminate the pop, just delays it)

2. **Hardware solution:** Some users report success by using a powered USB hub or adding ferrite cores to USB cables (reduces electrical noise)

3. **Different audio server:** Some users report better results with PulseAudio vs PipeWire or vice versa

## Credits

- Solution inspired by [AudioScienceReview XMOS driver thread](https://www.audiosciencereview.com/forum/index.php?threads/xmos-driver-settings-for-no-cutoff-delay.25838/)
- Testing and implementation by the Linux audio community

## Contributing

Found a bug or have an improvement? Please open an issue or submit a pull request!

## License

MIT License - Feel free to use, modify, and distribute.

---

**Enjoy your pop-free audio!** 🎵
