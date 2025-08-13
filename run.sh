#!/usr/bin/env bash

set -euo pipefail

# Simple runner that ensures dependencies, starts ydotoold (if available),
# and launches the key listener. Designed for Wayland/Xorg.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export YDOTOOL_SOCKET="/tmp/.ydotool_socket"

usage() {
  cat <<EOF
Usage: bash run.sh [--daemon]

Actions performed:
  - Ensures base system dependencies (alsa-utils, python3-evdev, wl-clipboard, libnotify-bin, wtype)
  - Ensures Python venv deps for speech-to-text
  - Starts ydotoold (if available) on socket ${YDOTOOL_SOCKET}
  - Runs key listener (foreground by default; background with --daemon)

Notes:
  - This script must run as root to access /dev/input/event*. If not root, it will re-exec with sudo.
  - On Wayland, typing may require ydotoold; if not available, clipboard+notification fallback is used.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Re-exec as root if needed
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

cd "$REPO_DIR"

echo "[run.sh] Installing base system dependencies (optional)…"
if command -v apt-get >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get update -y || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    alsa-utils python3-evdev wl-clipboard libnotify-bin wtype || true
else
  echo "[run.sh] Skipping apt-get (not available)."
fi

echo "[run.sh] Ensuring Python venv dependencies (for speech_to_text.py)…"
if [[ ! -x "$REPO_DIR/venv/bin/python3" ]]; then
  python3 -m venv "$REPO_DIR/venv"
fi
"$REPO_DIR/venv/bin/pip" install -r "$REPO_DIR/requirements.txt"

start_ydotoold() {
  if command -v ydotoold >/dev/null 2>&1; then
    echo "[run.sh] Starting ydotoold on $YDOTOOL_SOCKET"
    pkill -f ydotoold || true
    rm -f "$YDOTOOL_SOCKET" || true
    # Start and relax socket permissions for user-space access
    YDOTOOL_SOCKET="$YDOTOOL_SOCKET" ydotoold -p "$YDOTOOL_SOCKET" \
      >/dev/null 2>&1 &
    local retry=0
    while [[ ! -S "$YDOTOOL_SOCKET" && $retry -lt 50 ]]; do
      sleep 0.05
      retry=$((retry+1))
    done
    if [[ -S "$YDOTOOL_SOCKET" ]]; then
      chmod 666 "$YDOTOOL_SOCKET" || true
      echo "[run.sh] ydotoold socket ready: $YDOTOOL_SOCKET"
    else
      echo "[run.sh] ydotoold socket not found; continuing without it."
    fi
  else
    echo "[run.sh] ydotoold not found; typing will fall back to clipboard/notification."
  fi
}

start_listener_fg() {
  echo "[run.sh] Starting key listener in foreground…"
  exec python3 "$REPO_DIR/key_listener.py"
}

start_listener_bg() {
  echo "[run.sh] Starting key listener in background… logs: /tmp/key_listener.log"
  nohup python3 "$REPO_DIR/key_listener.py" >/tmp/key_listener.launch.log 2>&1 &
}

# Start services
start_ydotoold

if [[ "${1:-}" == "--daemon" ]]; then
  start_listener_bg
else
  start_listener_fg
fi


