#!/usr/bin/env bash

set -euo pipefail

# Interactive menu for Speech-to-Text system using gum
# https://github.com/charmbracelet/gum

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export YDOTOOL_SOCKET="/tmp/.ydotool_socket"

# Colors and styling
show_title() {
    gum style \
        --foreground=212 \
        --border-foreground=212 \
        --border=double \
        --align=center \
        --width=60 \
        --margin="1 2" \
        --padding="2 4" \
        "🎤 Speech-to-Text for Ubuntu 🎤"
    echo
}

show_subtitle() {
    gum style \
        --foreground=57 \
        --border-foreground=57 \
        --border=rounded \
        --align=center \
        --width=50 \
        --margin="1 2" \
        --padding="1 3" \
        "$1"
    echo
}

show_info() {
    gum style \
        --foreground=255 \
        --border-foreground=255 \
        --border=rounded \
        --align=left \
        --width=70 \
        --margin="1 2" \
        --padding="1 3" \
        "$1"
    echo
}

install_dependencies() {
    show_subtitle "Installing Dependencies"

    # Check if running as root
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "This action requires root privileges. Re-running with sudo..."
        exec sudo -E bash "$0" install
    fi

    cd "$REPO_DIR"

    echo "📦 Installing base system dependencies..."
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get update -y || true
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            alsa-utils python3-evdev wl-clipboard libnotify-bin wtype || true
        echo "✅ Base dependencies installed"
    else
        echo "⚠️  Skipping apt-get (not available)"
    fi

    echo "🐍 Setting up Python virtual environment..."
    if [[ ! -x "$REPO_DIR/venv/bin/python3" ]]; then
        python3 -m venv "$REPO_DIR/venv"
        echo "✅ Virtual environment created"
    fi

    echo "📚 Installing Python packages..."
    "$REPO_DIR/venv/bin/pip" install -r "$REPO_DIR/requirements.txt"
    echo "✅ Python dependencies installed"

    echo "🔧 Checking for ydotool..."
    if command -v ydotool >/dev/null 2>&1; then
        echo "✅ ydotool found"
    else
        echo "⚠️  ydotool not found - you may need to compile it from source"
        echo "   See README.md for compilation instructions"
    fi

    echo
    gum confirm "Dependencies installed! Return to main menu?" && return 0 || exit 0
}

start_ydotoold() {
    if command -v ydotoold >/dev/null 2>&1; then
        echo "🚀 Starting ydotoold on $YDOTOOL_SOCKET"
        pkill -f ydotoold || true
        rm -f "$YDOTOOL_SOCKET" || true

        # Start and relax socket permissions for user-space access
        YDOTOOL_SOCKET="$YDOTOOL_SOCKET" ydotoold -p "$YDOTOOL_SOCKET" >/dev/null 2>&1 &

        local retry=0
        while [[ ! -S "$YDOTOOL_SOCKET" && $retry -lt 50 ]]; do
            sleep 0.05
            retry=$((retry+1))
        done

        if [[ -S "$YDOTOOL_SOCKET" ]]; then
            chmod 666 "$YDOTOOL_SOCKET" || true
            echo "✅ ydotoold socket ready: $YDOTOOL_SOCKET"
        else
            echo "❌ ydotoold socket not found; continuing without it."
        fi
    else
        echo "⚠️  ydotoold not found; typing will fall back to clipboard/notification."
    fi
}

run_with_typing() {
    show_subtitle "Running with Auto-Typing"
    show_info "This mode will automatically type transcribed text into the focused window."

    if gum confirm "Start speech-to-text with auto-typing?"; then
        start_ydotoold

        echo "🎯 Starting key listener with auto-typing mode..."
        echo "   Press Shift+Ctrl+F12 (mapped to F16) to start recording"
        echo "   Release to stop recording and auto-type"
        echo "   Press Ctrl+C to stop"
        echo

        STT_MODE="type" sudo -E python3 "$REPO_DIR/key_listener.py"
    fi
}

run_with_clipboard() {
    show_subtitle "Running with Manual Pasting"
    show_info "This mode will copy transcribed text to clipboard and notify you to paste manually."

    if gum confirm "Start speech-to-text with clipboard mode?"; then
        start_ydotoold

        echo "📋 Starting key listener with clipboard mode..."
        echo "   Press Shift+Ctrl+F12 (mapped to F16) to start recording"
        echo "   Release to stop recording and copy to clipboard"
        echo "   Look for notification, then press Ctrl+V to paste"
        echo "   Press Ctrl+C to stop"
        echo

        STT_MODE="clipboard" sudo -E python3 "$REPO_DIR/key_listener.py"
    fi
}

run_background() {
    show_subtitle "Running in Background"

    local mode_choice=$(gum choose \
        "Auto-typing mode" \
        "Clipboard mode" \
        "Cancel")

    case "$mode_choice" in
        "Auto-typing mode")
            start_ydotoold
            echo "🔄 Starting key listener in background with auto-typing..."
            STT_MODE="type" nohup sudo -E python3 "$REPO_DIR/key_listener.py" >/tmp/key_listener.launch.log 2>&1 &
            echo "✅ Key listener started in background (PID: $!)"
            echo "   Logs: $REPO_DIR/log/key_listener.log"
            echo "   To stop: sudo pkill -f 'python3 key_listener.py'"
            ;;
        "Clipboard mode")
            start_ydotoold
            echo "🔄 Starting key listener in background with clipboard mode..."
            STT_MODE="clipboard" nohup sudo -E python3 "$REPO_DIR/key_listener.py" >/tmp/key_listener.launch.log 2>&1 &
            echo "✅ Key listener started in background (PID: $!)"
            echo "   Logs: $REPO_DIR/log/key_listener.log"
            echo "   To stop: sudo pkill -f 'python3 key_listener.py'"
            ;;
        "Cancel")
            return 0
            ;;
    esac

    echo
    gum confirm "Return to main menu?" && return 0 || exit 0
}

check_status() {
    show_subtitle "System Status"

    echo "🔍 Checking system status..."
    echo

    # Check if key listener is running
    if pgrep -f "python3 key_listener.py" >/dev/null; then
        echo "✅ Key listener is running"
        ps aux | grep "python3 key_listener.py" | grep -v grep
    else
        echo "❌ Key listener is not running"
    fi
    echo

    # Check if ydotoold is running
    if pgrep -x "ydotoold" >/dev/null; then
        echo "✅ ydotoold is running"
        if [[ -S "$YDOTOOL_SOCKET" ]]; then
            echo "✅ ydotoold socket exists: $YDOTOOL_SOCKET"
        else
            echo "❌ ydotoold socket missing: $YDOTOOL_SOCKET"
        fi
    else
        echo "❌ ydotoold is not running"
    fi
    echo

    # Check dependencies
    echo "📦 Dependencies:"
    local deps=("python3" "python3-evdev" "wl-copy" "notify-send" "wtype" "ydotool")
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            echo "   ✅ $dep"
        else
            echo "   ❌ $dep"
        fi
    done

    echo
    gum confirm "Return to main menu?" && return 0 || exit 0
}

show_help() {
    show_subtitle "Help & Information"

    cat <<EOF | gum style $INFO_STYLE
Speech-to-Text for Ubuntu

This system provides push-to-talk speech recognition using:
• Faster Whisper for transcription
• Multiple input methods (auto-typing or clipboard)
• Wayland/X11 compatibility

Usage:
1. Install dependencies first
2. Choose your preferred mode:
   • Auto-typing: Text appears automatically in focused window
   • Clipboard: Text copied to clipboard with notification

Hotkey: Shift+Ctrl+F12 (mapped to F16)
• Press and hold to record
• Release to process and output

For more details, see README.md
EOF

    echo
    gum confirm "Return to main menu?" && return 0 || exit 0
}

main_menu() {
    while true; do
        clear
        show_title

        local choice=$(gum choose \
            "1️⃣ Install Dependencies" \
            "2️⃣ Run with Auto-Typing" \
            "3️⃣ Run with Manual Pasting" \
            "4️⃣ Run in Background" \
            "5️⃣ Check System Status" \
            "6️⃣ Help & Information" \
            "7️⃣ Exit")

        case "$choice" in
            "1️⃣ Install Dependencies")
                install_dependencies
                ;;
            "2️⃣ Run with Auto-Typing")
                run_with_typing
                ;;
            "3️⃣ Run with Manual Pasting")
                run_with_clipboard
                ;;
            "4️⃣ Run in Background")
                run_background
                ;;
            "5️⃣ Check System Status")
                check_status
                ;;
            "6️⃣ Help & Information")
                show_help
                ;;
            "7️⃣ Exit")
                echo "👋 Goodbye!"
                exit 0
                ;;
        esac
    done
}

# Handle command line arguments
case "${1:-}" in
    install)
        install_dependencies
        ;;
    type)
        run_with_typing
        ;;
    clipboard)
        run_with_clipboard
        ;;
    background)
        run_background
        ;;
    status)
        check_status
        ;;
    help)
        show_help
        ;;
    *)
        main_menu
        ;;
esac
