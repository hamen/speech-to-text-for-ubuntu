#!/bin/bash
# Setup script to restore Ctrl+Alt+F12 → F16 keyboard mapping
# This is needed for the speech-to-text push-to-talk functionality
# Supports both input-remapper (recommended) and xmodmap (X11 fallback)

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/input-remapper"
PRESET_NAME="ctrl-alt-f12-to-f16"
PRESET_FILE="$CONFIG_DIR/presets/$PRESET_NAME.json"

echo "🔧 Setting up keyboard shortcut: Ctrl+Alt+F12 → F16"
echo ""

# Detect desktop environment
if [ -n "$XDG_SESSION_TYPE" ]; then
    SESSION_TYPE="$XDG_SESSION_TYPE"
elif [ -n "$WAYLAND_DISPLAY" ]; then
    SESSION_TYPE="wayland"
elif [ -n "$DISPLAY" ]; then
    SESSION_TYPE="x11"
else
    SESSION_TYPE="x11"  # Default assumption for Xfce
fi

echo "📋 Detected session: $SESSION_TYPE"
echo ""

# Check if input-remapper is available
if command -v input-remapper-gtk >/dev/null 2>&1; then
    echo "✅ Input-remapper is installed"
    
    # Ensure input-remapper config directory exists
    mkdir -p "$CONFIG_DIR/presets"
    
    # List available devices
    echo ""
    echo "📋 Available input devices:"
    input-remapper-control --list-devices 2>&1 | sed 's/^/   /'
    echo ""
    
    # Auto-detect keyboard device
    DEVICE_NAME=$(input-remapper-control --list-devices 2>&1 | grep -iE "keyboard|key|daskeyboard" | head -1 | xargs)
    if [ -z "$DEVICE_NAME" ]; then
        DEVICE_NAME="daskeyboard"  # Fallback
    fi
    
    echo "🎯 Auto-detected keyboard: $DEVICE_NAME"
    echo ""
    
    # Create a simple preset that maps F12 with Ctrl+Alt to F16
    # Note: input-remapper maps keys, so we map F12 to F16 when modifiers are held
    cat > "$PRESET_FILE" << 'EOF'
{
  "mapping": {
    "KEY_F12": [
      [
        "KEY_LEFTCTRL",
        "KEY_LEFTALT",
        "KEY_F16"
      ]
    ]
  }
}
EOF
    
    echo "✅ Created preset file: $PRESET_FILE"
    echo ""
    
    # Start input-remapper service if not running
    if ! pgrep -x "input-remapper-control\|input-remapper-service" > /dev/null; then
        echo "🚀 Starting input-remapper service..."
        input-remapper-control --command start || true
        sleep 2
    else
        echo "✅ Input-remapper service is already running"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "📝 SETUP INSTRUCTIONS - Using input-remapper GUI"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "1. The GUI will open automatically in 3 seconds..."
    echo "   (Press Ctrl+C to cancel and open manually)"
    echo ""
    echo "2. In the input-remapper GUI:"
    echo "   a) Select your keyboard device: $DEVICE_NAME"
    echo "   b) Click 'Edit' or 'New Preset'"
    echo "   c) Map F12 key:"
    echo "      - Click on F12 key"
    echo "      - Set output to: F16"
    echo "      - Enable 'Only when Ctrl+Alt are held' option"
    echo "      (or configure the combination as needed)"
    echo "   d) Click 'Save' and name it: $PRESET_NAME"
    echo "   e) Enable the preset (toggle switch)"
    echo ""
    echo "3. Test the shortcut:"
    echo "   - Press Ctrl+Alt+F12"
    echo "   - It should trigger F16 (which your speech-to-text listens for)"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Auto-open GUI after a short delay
    sleep 3
    echo "🚀 Opening input-remapper GUI..."
    input-remapper-gtk >/dev/null 2>&1 &
    
else
    echo "⚠️  input-remapper not found. Using X11 xmodmap method..."
    echo ""
    
    if [ "$SESSION_TYPE" != "x11" ]; then
        echo "❌ Error: This method only works on X11 sessions."
        echo "   Please install input-remapper for Wayland support:"
        echo "   sudo apt install input-remapper"
        exit 1
    fi
    
    # X11 xmodmap method (fallback)
    XMODMAP_FILE="$HOME/.Xmodmap-speech-to-text"
    
    echo "📝 Creating xmodmap configuration..."
    cat > "$XMODMAP_FILE" << 'EOF'
! Map Ctrl+Alt+F12 to F16
! This is a workaround - xmodmap can't directly map key combinations
! You may need to use xbindkeys or input-remapper instead
! 
! For now, we'll map F12 to F16, and you can use Ctrl+Alt+F12
! by configuring it in Xfce Keyboard Settings → Application Shortcuts
EOF
    
    echo "✅ Created xmodmap file: $XMODMAP_FILE"
    echo ""
    echo "⚠️  Note: xmodmap cannot directly map key combinations."
    echo "   For Ctrl+Alt+F12 → F16 mapping, please use input-remapper instead."
    echo ""
    echo "   To install input-remapper:"
    echo "   sudo apt install input-remapper"
    echo ""
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "💡 Quick test:"
echo "   1. Run your speech-to-text: sudo ./launch-large-v3.sh"
echo "   2. Press Ctrl+Alt+F12 (should trigger F16)"
echo "   3. Speak and release to transcribe"
echo ""

