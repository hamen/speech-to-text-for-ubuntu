#!/usr/bin/env bash

set -euo pipefail

# Interactive menu for Speech-to-Text system using gum
# https://github.com/charmbracelet/gum

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export YDOTOOL_SOCKET="/tmp/.ydotool_socket"
CONFIG_FILE="$HOME/.config/speech-to-text/config.conf"

load_persistent_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Export every variable loaded from config so sudo -E preserves them
        set -a
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        set +a
    fi
}

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
    load_persistent_config

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
    load_persistent_config

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

run_nemotron() {
    show_subtitle "🎙️ Nemotron Speech-to-Text"
    show_info "Transcription is served by the Nemotron STT server over the Unix socket /tmp/stt_server.sock. The server runs as the systemd user service 'nemotron-stt'."
    load_persistent_config

    # The Nemotron server must already be running (managed by systemd).
    if [[ ! -S /tmp/stt_server.sock ]]; then
        echo "❌ Nemotron STT server socket not found: /tmp/stt_server.sock"
        echo "   Start the server first:"
        echo "     systemctl --user start nemotron-stt"
        echo
        gum confirm "Return to main menu?" && return 0 || exit 0
        return 1
    fi
    echo "✅ Nemotron STT server socket found: /tmp/stt_server.sock"
    echo

    if gum confirm "Launch key listener (Nemotron)?"; then
        start_ydotoold

        echo "🚀 Launching key listener..."
        echo "   Press F16 (or Double-Control or Double-Super) to start recording"
        echo "   Press Ctrl+C to stop"
        echo

        # speech_to_text.py talks to the Nemotron server over the socket.
        sudo -E python3 "$REPO_DIR/key_listener.py"
    fi
}

run_background() {
    show_subtitle "Running in Background"
    load_persistent_config

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

    # Check GPU status
    if command -v nvidia-smi &> /dev/null; then
        echo "🎮 GPU Status:"
        nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader,nounits | while IFS=, read -r name used total; do
            available=$((total - used))
            echo "   $name: ${used}MB / ${total}MB (${available}MB available)"
        done
    else
        echo "🎮 GPU: Not detected"
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
    # Check Nemotron STT server socket
    if [[ -S /tmp/stt_server.sock ]]; then
        echo "✅ Nemotron STT server socket exists: /tmp/stt_server.sock"
    else
        echo "❌ Nemotron STT server socket missing: /tmp/stt_server.sock"
        echo "   Start it with: systemctl --user start nemotron-stt"
    fi

    echo
    gum confirm "Return to main menu?" && return 0 || exit 0
}

kill_background_service() {
    show_subtitle "Stop Background Service"

    # Check for auto-restart mechanisms
    echo "🔍 Checking for auto-restart mechanisms..."
    local cron_found=false
    local systemd_found=false
    
    # Check root crontab
    if sudo crontab -l 2>/dev/null | grep -qi "key_listener\|speech.*text"; then
        cron_found=true
        echo "⚠️  WARNING: Found cron job that may restart the service!"
        echo "   Root cron entries found:"
        sudo crontab -l 2>/dev/null | grep -i "key_listener\|speech.*text" | sed 's/^/   /'
        echo ""
    fi
    
    # Check user crontab
    if crontab -l 2>/dev/null | grep -qi "key_listener\|speech.*text"; then
        cron_found=true
        echo "⚠️  WARNING: Found user cron job that may restart the service!"
        echo "   User cron entries found:"
        crontab -l 2>/dev/null | grep -i "key_listener\|speech.*text" | sed 's/^/   /'
        echo ""
    fi
    
    # Check systemd services
    if systemctl list-units --type=service --all 2>/dev/null | grep -qi "speech.*text\|key.*listener"; then
        systemd_found=true
        echo "⚠️  WARNING: Found systemd service that may restart the service!"
        echo "   Systemd services found:"
        systemctl list-units --type=service --all 2>/dev/null | grep -i "speech.*text\|key.*listener" | sed 's/^/   /'
        echo ""
    fi
    
    # Check for systemd user services
    if systemctl --user list-units --type=service --all 2>/dev/null | grep -qi "speech.*text\|key.*listener"; then
        systemd_found=true
        echo "⚠️  WARNING: Found systemd user service that may restart the service!"
        echo "   Systemd user services found:"
        systemctl --user list-units --type=service --all 2>/dev/null | grep -i "speech.*text\|key.*listener" | sed 's/^/   /'
        echo ""
    fi
    
    # Check for desktop autostart files
    local autostart_files=""
    for autostart_dir in "$HOME/.config/autostart" "/etc/xdg/autostart"; do
        if [[ -d "$autostart_dir" ]]; then
            local found=$(find "$autostart_dir" -name "*.desktop" -exec grep -l "key_listener\|speech.*text" {} \; 2>/dev/null || true)
            if [[ -n "$found" ]]; then
                autostart_files="$autostart_files $found"
            fi
        fi
    done
    if [[ -n "$autostart_files" ]]; then
        echo "⚠️  WARNING: Found desktop autostart files that may restart the service!"
        echo "   Autostart files:"
        for file in $autostart_files; do
            echo "   $file"
        done
        echo ""
    fi
    
    # Check for any process that might be watching/restarting
    local watcher_pids=$(pgrep -f "watch.*key_listener\|while.*key_listener\|restart.*key_listener\|nohup.*key_listener" 2>/dev/null || true)
    if [[ -n "$watcher_pids" ]]; then
        echo "⚠️  WARNING: Found processes that may be watching/restarting the service!"
        echo "   Watcher processes:"
        for wpid in $watcher_pids; do
            ps -fp "$wpid" 2>/dev/null | sed 's/^/   /' || sudo ps -fp "$wpid" 2>/dev/null | sed 's/^/   /' || echo "   PID $wpid"
        done
        echo ""
    fi
    
    # Find all processes matching key_listener.py (including root processes)
    local pids=$(pgrep -f "python3.*key_listener.py" 2>/dev/null || true)
    
    if [[ -z "$pids" ]]; then
        # Also check as root user
        pids=$(sudo pgrep -f "python3.*key_listener.py" 2>/dev/null || true)
    fi

    if [[ -z "$pids" ]]; then
        echo "ℹ️  No background speech-to-text service is currently running"
        if [[ "$cron_found" == "true" || "$systemd_found" == "true" || -n "$autostart_files" ]]; then
            echo ""
            echo "⚠️  Note: Auto-restart mechanism(s) detected but no process is running."
            echo "   The service may restart automatically."
        fi
        echo
        gum confirm "Return to main menu?" && return 0 || exit 0
        return 0
    fi

    echo "🔍 Found running background service(s):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show detailed process information with PIDs and parent PIDs
    local all_parent_pids=""
    for pid in $pids; do
        if ps -p "$pid" >/dev/null 2>&1 || sudo ps -p "$pid" >/dev/null 2>&1; then
            echo ""
            echo "📋 Process ID (PID): $pid"
            local ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || sudo ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
            if [[ -n "$ppid" && "$ppid" != "1" ]]; then
                echo "   Parent PID (PPID): $ppid"
                all_parent_pids="$all_parent_pids $ppid"
            fi
            # Show process state
            local state=$(ps -o stat= -p "$pid" 2>/dev/null || sudo ps -o stat= -p "$pid" 2>/dev/null || echo "")
            if [[ -n "$state" ]]; then
                echo "   State: $state"
                if echo "$state" | grep -q "D"; then
                    echo "   ⚠️  Process is in uninterruptible sleep (may be stuck)"
                fi
            fi
            ps -fp "$pid" 2>/dev/null || sudo ps -fp "$pid" 2>/dev/null || echo "   (Unable to get full details)"
        fi
    done
    
    # Check process tree to see what's spawning the processes
    echo ""
    echo "🔍 Analyzing process tree to identify spawner..."
    for pid in $pids; do
        if ps -p "$pid" >/dev/null 2>&1 || sudo ps -p "$pid" >/dev/null 2>&1; then
            local ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || sudo ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
            if [[ -n "$ppid" && "$ppid" != "1" ]]; then
                echo "   PID $pid → Parent PID $ppid:"
                local pcmd=$(ps -o cmd= -p "$ppid" 2>/dev/null || sudo ps -o cmd= -p "$ppid" 2>/dev/null || echo "")
                ps -fp "$ppid" 2>/dev/null | sed 's/^/      /' || sudo ps -fp "$ppid" 2>/dev/null | sed 's/^/      /' || echo "      (Unable to get parent details)"
                # Check grandparent too
                local gppid=$(ps -o ppid= -p "$ppid" 2>/dev/null | tr -d ' ' || sudo ps -o ppid= -p "$ppid" 2>/dev/null | tr -d ' ')
                if [[ -n "$gppid" && "$gppid" != "1" ]]; then
                    local gpcmd=$(ps -o cmd= -p "$gppid" 2>/dev/null || sudo ps -o cmd= -p "$gppid" 2>/dev/null || echo "")
                    echo "      → Grandparent PID $gppid:"
                    ps -fp "$gppid" 2>/dev/null | sed 's/^/         /' || sudo ps -fp "$gppid" 2>/dev/null | sed 's/^/         /' || echo "         (Unable to get grandparent details)"
                    # Check if grandparent looks like a restart script
                    if echo "$gpcmd" | grep -qiE "(bash|sh|zsh|fish|watch|while|loop|restart|nohup)"; then
                        echo "         ⚠️  This looks like a restart script!"
                        all_parent_pids="$all_parent_pids $gppid"
                    fi
                fi
            fi
        fi
    done
    
    # Also show with ps aux for full command line
    echo ""
    echo "Full process details:"
    ps aux | grep "python3.*key_listener.py" | grep -v grep || sudo ps aux | grep "python3.*key_listener.py" | grep -v grep || true
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📌 PIDs to kill: $pids"
    local restart_mechanism=""
    if [[ "$cron_found" == "true" ]]; then
        restart_mechanism="cron job"
    fi
    if [[ "$systemd_found" == "true" ]]; then
        if [[ -n "$restart_mechanism" ]]; then
            restart_mechanism="$restart_mechanism and/or systemd service"
        else
            restart_mechanism="systemd service"
        fi
    fi
    if [[ -n "$watcher_pids" ]]; then
        if [[ -n "$restart_mechanism" ]]; then
            restart_mechanism="$restart_mechanism and/or watcher process"
        else
            restart_mechanism="watcher process"
        fi
    fi
    if [[ -n "$restart_mechanism" ]]; then
        echo ""
        echo "⚠️  IMPORTANT: A $restart_mechanism will restart this service automatically!"
        echo "   You may need to disable it to prevent auto-restart."
    fi
    echo ""

    if gum confirm "Stop the background speech-to-text service(s)?"; then
        echo "🛑 Stopping background service(s)..."
        
        local killed_any=false
        local failed_pids=""
        local parent_pids=""
        
        # Use the parent PIDs we collected earlier, plus check for any new ones
        parent_pids="$all_parent_pids"
        
        # Also collect any additional parent PIDs from current processes
        for pid in $pids; do
            if ps -p "$pid" >/dev/null 2>&1 || sudo ps -p "$pid" >/dev/null 2>&1; then
                local ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || sudo ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
                if [[ -n "$ppid" && "$ppid" != "1" ]]; then
                    # Check if parent is a shell that started the process
                    local parent_cmd=$(ps -o cmd= -p "$ppid" 2>/dev/null || sudo ps -o cmd= -p "$ppid" 2>/dev/null || echo "")
                    if echo "$parent_cmd" | grep -qE "(bash|sh|nohup|sudo|watch|while|loop)"; then
                        # Add if not already in the list
                        if ! echo "$parent_pids" | grep -q "\b$ppid\b"; then
                            parent_pids="$parent_pids $ppid"
                        fi
                    fi
                fi
            fi
        done
        
        # Try to kill each PID individually, including the entire process tree
        for pid in $pids; do
            if ps -p "$pid" >/dev/null 2>&1 || sudo ps -p "$pid" >/dev/null 2>&1; then
                echo "   Attempting to kill PID $pid and its children..."
                
                # Kill all children first
                local children=$(pgrep -P "$pid" 2>/dev/null || true)
                if [[ -n "$children" ]]; then
                    echo "      Killing children: $children"
                    for child in $children; do
                        sudo kill "$child" 2>/dev/null || true
                    done
                fi
                
                # Try graceful kill
                if sudo kill "$pid" 2>/dev/null; then
                    echo "   ✅ Sent TERM signal to PID $pid"
                    killed_any=true
                else
                    local kill_error=$(sudo kill "$pid" 2>&1)
                    echo "   ⚠️  Failed to send TERM to PID $pid: $kill_error"
                    # Check if process still exists
                    if ps -p "$pid" >/dev/null 2>&1 || sudo ps -p "$pid" >/dev/null 2>&1; then
                        failed_pids="$failed_pids $pid"
                    else
                        echo "   ℹ️  Process $pid already terminated"
                    fi
                fi
            else
                echo "   ℹ️  PID $pid no longer exists"
            fi
        done
        
        # Also kill parent processes (shells that started them)
        if [[ -n "$parent_pids" ]]; then
            echo ""
            echo "   Killing parent processes (shells): $parent_pids"
            for ppid in $parent_pids; do
                if ps -p "$ppid" >/dev/null 2>&1 || sudo ps -p "$ppid" >/dev/null 2>&1; then
                    sudo kill "$ppid" 2>/dev/null && echo "   ✅ Killed parent PID $ppid" || true
                fi
            done
        fi
        
        # Kill watcher processes if found
        if [[ -n "$watcher_pids" ]]; then
            echo ""
            echo "   Killing watcher processes: $watcher_pids"
            for wpid in $watcher_pids; do
                if ps -p "$wpid" >/dev/null 2>&1 || sudo ps -p "$wpid" >/dev/null 2>&1; then
                    sudo kill "$wpid" 2>/dev/null && echo "   ✅ Killed watcher PID $wpid" || true
                fi
            done
        fi
        
        # Wait a moment for graceful shutdown
        if [[ "$killed_any" == "true" ]]; then
            echo ""
            echo "   Waiting 3 seconds for graceful shutdown..."
            sleep 3
        fi
        
        # Check if any are still running and force kill if needed
        local still_running=""
        for pid in $pids; do
            if ps -p "$pid" >/dev/null 2>&1 || sudo ps -p "$pid" >/dev/null 2>&1; then
                still_running="$still_running $pid"
            fi
        done
        
        if [[ -n "$still_running" ]]; then
            echo ""
            echo "   ⚠️  Some processes still running, attempting force kill..."
            for pid in $still_running; do
                echo "   Force killing PID $pid..."
                # Kill children first
                local children=$(pgrep -P "$pid" 2>/dev/null || true)
                if [[ -n "$children" ]]; then
                    for child in $children; do
                        sudo kill -9 "$child" 2>/dev/null && echo "      ✅ Force-killed child PID $child" || true
                    done
                fi
                # Now kill the process itself
                if sudo kill -9 "$pid" 2>/dev/null; then
                    echo "   ✅ Force-killed PID $pid"
                else
                    local kill_error=$(sudo kill -9 "$pid" 2>&1)
                    echo "   ❌ Failed to force-kill PID $pid: $kill_error"
                    # Check if it's a permission issue
                    if echo "$kill_error" | grep -qi "permission\|operation not permitted"; then
                        echo "      ⚠️  Permission denied - process may be protected"
                    fi
                    # Check if process still exists
                    if ps -p "$pid" >/dev/null 2>&1 || sudo ps -p "$pid" >/dev/null 2>&1; then
                        failed_pids="$failed_pids $pid"
                    else
                        echo "      ℹ️  Process $pid terminated despite error message"
                    fi
                fi
            done
            # Also force kill parent processes
            for ppid in $parent_pids; do
                if ps -p "$ppid" >/dev/null 2>&1 || sudo ps -p "$ppid" >/dev/null 2>&1; then
                    sudo kill -9 "$ppid" 2>/dev/null && echo "   ✅ Force-killed parent PID $ppid" || true
                fi
            done
            # Force kill watcher processes
            if [[ -n "$watcher_pids" ]]; then
                for wpid in $watcher_pids; do
                    if ps -p "$wpid" >/dev/null 2>&1 || sudo ps -p "$wpid" >/dev/null 2>&1; then
                        sudo kill -9 "$wpid" 2>/dev/null && echo "   ✅ Force-killed watcher PID $wpid" || true
                    fi
                done
            fi
            sleep 2
        fi
        
        # Final verification - check multiple times to catch restarts
        echo ""
        echo "🔍 Verifying processes are stopped (checking for restarts)..."
        sleep 2
        
        # Check multiple times with delays to catch restarts
        local remaining_pids=$(pgrep -f "python3.*key_listener.py" 2>/dev/null || sudo pgrep -f "python3.*key_listener.py" 2>/dev/null || true)
        
        # If processes restarted, try killing again
        if [[ -n "$remaining_pids" ]]; then
            echo "   ⚠️  Processes detected after initial kill, attempting aggressive kill..."
            for pid in $remaining_pids; do
                echo "   Aggressively killing PID $pid..."
                sudo kill -9 "$pid" 2>/dev/null && echo "   ✅ Killed PID $pid" || echo "   ❌ Failed to kill PID $pid"
            done
            sleep 3
            
            # Check one more time
            remaining_pids=$(pgrep -f "python3.*key_listener.py" 2>/dev/null || sudo pgrep -f "python3.*key_listener.py" 2>/dev/null || true)
        fi
        
        if [[ -z "$remaining_pids" ]]; then
            echo "✅ All background services stopped successfully!"
            if [[ "$cron_found" == "true" || "$systemd_found" == "true" || -n "$watcher_pids" ]]; then
                echo ""
                echo "⚠️  WARNING: Auto-restart mechanism(s) detected!"
                if [[ "$cron_found" == "true" ]]; then
                    echo "   • Cron job may restart the service within 1 minute"
                fi
                if [[ "$systemd_found" == "true" ]]; then
                    echo "   • Systemd service may restart the service"
                fi
                if [[ -n "$watcher_pids" ]]; then
                    echo "   • Watcher process(es) may restart the service"
                fi
                echo ""
                echo "💡 To permanently disable auto-restart:"
                if [[ "$cron_found" == "true" ]]; then
                    echo "   • Disable cron: sudo crontab -e (remove key_listener.py line)"
                fi
                if [[ "$systemd_found" == "true" ]]; then
                    echo "   • Disable systemd: sudo systemctl disable <service-name>"
                fi
                if [[ -n "$watcher_pids" ]]; then
                    echo "   • Kill watcher processes: sudo kill -9 $watcher_pids"
                fi
            fi
        else
            echo "❌ Warning: Processes are still running (may have been restarted):"
            for pid in $remaining_pids; do
                echo "   PID $pid is still running"
                if ps -p "$pid" >/dev/null 2>&1 || sudo ps -p "$pid" >/dev/null 2>&1; then
                    ps -fp "$pid" 2>/dev/null || sudo ps -fp "$pid" 2>/dev/null || echo "   (Unable to get details)"
                fi
            done
            echo ""
            if [[ "$cron_found" == "true" || "$systemd_found" == "true" || -n "$watcher_pids" ]]; then
                echo "⚠️  Auto-restart mechanism likely restarted the service!"
                echo ""
                echo "💡 To stop permanently, you need to:"
                echo "   1. Kill the processes: sudo kill -9 $remaining_pids"
                if [[ "$cron_found" == "true" ]]; then
                    echo "   2. Disable cron job: sudo crontab -e"
                    echo "      Then remove/comment the line with 'key_listener.py'"
                fi
                if [[ "$systemd_found" == "true" ]]; then
                    echo "   2. Disable systemd service: sudo systemctl disable <service-name>"
                fi
                if [[ -n "$watcher_pids" ]]; then
                    echo "   2. Kill watcher processes: sudo kill -9 $watcher_pids"
                fi
            else
                echo "💡 Kill them manually with:"
                echo "   sudo kill -9 $remaining_pids"
                echo ""
                echo "⚠️  Note: If processes keep restarting, check for:"
                echo "   • Cron jobs: sudo crontab -l and crontab -l"
                echo "   • Systemd services: systemctl list-units --type=service"
                echo "   • Watcher scripts: ps aux | grep -i watch"
            fi
        fi
        
        if [[ -n "$failed_pids" ]]; then
            echo ""
            echo "⚠️  Some PIDs could not be killed: $failed_pids"
            echo "   Try manually: sudo kill -9 $failed_pids"
        fi
    else
        echo "ℹ️  Operation cancelled"
    fi

    echo
    gum confirm "Return to main menu?" && return 0 || exit 0
}

manage_configuration() {
    show_subtitle "Configuration Management"
    show_info "Manage your speech-to-text preferences including sound vs notifications, text cleaning, and model settings."

    if gum confirm "Open configuration management menu?"; then
        # Load current configuration and open the interactive menu
        if [[ -f "./config-manager.sh" ]]; then
            ./config-manager.sh menu
        else
            show_error "Configuration manager not found: ./config-manager.sh"
            echo "Please ensure the configuration manager script exists."
        fi
    fi
}

show_help() {
    show_subtitle "Help & Information"

    cat <<EOF | gum style --foreground=255 --border-foreground=255 --border=rounded --align=left --width=70 --margin="1 2" --padding="1 3"
Speech-to-Text for Ubuntu

This system provides push-to-talk speech recognition using:
• The Nemotron STT server (Unix socket /tmp/stt_server.sock)
• Multiple input methods (auto-typing or clipboard)
• Wayland/X11 compatibility

The Nemotron server runs as the systemd user service 'nemotron-stt'.
Start it with: systemctl --user start nemotron-stt

Available Output Modes:
1. Auto-typing: Text appears automatically in focused window
2. Clipboard: Text copied to clipboard with notification

Hotkey: Shift+Ctrl+F12 (mapped to F16)
• Press and hold to record
• Release to process and output

For more details, see README.md.
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
            "4️⃣ 🎙️ Run Nemotron STT" \
            "5️⃣ Run in Background" \
            "6️⃣ Check System Status" \
            "7️⃣ 🛑 Stop Background Service" \
            "8️⃣ ⚙️  Configuration Management" \
            "9️⃣ Help & Information" \
            "🔟 Exit")

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
            "4️⃣ 🎙️ Run Nemotron STT")
                run_nemotron
                ;;
            "5️⃣ Run in Background")
                run_background
                ;;
            "6️⃣ Check System Status")
                check_status
                ;;
            "7️⃣ 🛑 Stop Background Service")
                kill_background_service
                ;;
            "8️⃣ ⚙️  Configuration Management")
                manage_configuration
                ;;
            "9️⃣ Help & Information")
                show_help
                ;;
            "🔟 Exit")
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
    nemotron)
        run_nemotron
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
