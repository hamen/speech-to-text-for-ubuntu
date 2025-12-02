# Keyboard Shortcut Setup Guide

## Restoring Ctrl+Alt+F12 → F16 Mapping

If you've lost your keyboard shortcut configuration, use the automated setup script:

```bash
./setup-keyboard-shortcut.sh
```

This script will:
1. ✅ Detect your keyboard device automatically
2. ✅ Create the preset configuration file
3. ✅ Start input-remapper service
4. ✅ Open the GUI for final configuration

## Native "Double-Tap" Shortcuts (New)

As an alternative to the F16 mapping, the system now supports two macOS-style dictation shortcuts:

### Option A: Double-Tap Super (Windows Key)
1. **Press the Super (Windows) key twice.**
2. **On the second press, HOLD the key down.**
3. **Speak while holding the key.**
4. **Release the key to stop recording.**

### Option B: Double-Tap Left Control
1. **Press the Left Control key twice.**
2. **On the second press, HOLD the key down.**
3. **Speak while holding the key.**
4. **Release the key to stop recording.**

These work natively and can be used alongside or instead of the F16 mapping. Double-Control is often more reliable if the Super key is intercepted by the desktop environment.

### Multi-Device Support
The system now listens on **all connected keyboards** simultaneously. This means you can use:
- Your laptop keyboard
- An external USB keyboard
- A Bluetooth keyboard
- The virtual input-remapper device (for F16)

It intelligently merges input from all sources, so you can even double-tap Control on one keyboard and hold it on another (though that would be weird).

## Manual Setup (Alternative)

If you prefer to set it up manually:

### Step 1: Open input-remapper GUI
```bash
input-remapper-gtk
```

### Step 2: Configure the mapping
1. **Select your keyboard device** (e.g., "daskeyboard" or "Logitech MX Keys")
2. **Click "Edit" or "New Preset"**
3. **Find F12 key** in the keyboard layout
4. **Click on F12** and configure:
   - **Output**: Set to `F16`
   - **Condition**: Enable "Only when Ctrl+Alt are held" (or configure combination)
5. **Save the preset** with name: `ctrl-alt-f12-to-f16`
6. **Enable the preset** (toggle switch at the top)

### Step 3: Test
1. Run your speech-to-text: `sudo ./launch-large-v3.sh`
2. Press **Ctrl+Alt+F12**
3. The system should detect it as F16 and start recording

## Troubleshooting

### Input-remapper service not running
```bash
input-remapper-control --command start
```

### Check if mapping is active
```bash
# List active devices
input-remapper-control --list-devices

# Check service status
pgrep -a input-remapper
```

### Verify F16 detection
```bash
# Test key detection (run as root)
sudo evtest /dev/input/event12
# Press Ctrl+Alt+F12 and look for KEY_F16 events
```

### Reset configuration
```bash
# Remove preset
rm ~/.config/input-remapper/presets/ctrl-alt-f12-to-f16.json

# Restart service
input-remapper-control --command stop-all
input-remapper-control --command start
```

## Configuration File Location

- **Preset file**: `~/.config/input-remapper/presets/ctrl-alt-f12-to-f16.json`
- **Main config**: `~/.config/input-remapper/config.json`

## Notes

- The mapping persists across reboots once enabled in input-remapper GUI
- You may need to run `sudo ./launch-large-v3.sh` as root for key detection
- If Ctrl+Alt+F12 doesn't work, try restarting input-remapper service
- For Xfce/X11, input-remapper works reliably for key combination mapping
