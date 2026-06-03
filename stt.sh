#!/usr/bin/env bash
# Nuc STT backend switcher (Mac Mini).
# Every backend serves POST /inference on :8089, so hey_nuc.py never changes —
# this just swaps which model is listening there.
#
#   ./stt.sh           # interactive menu
#   ./stt.sh small     # or: turbo | parakeet
NUC="$HOME/nuc"; PORT=8089
WS=/opt/homebrew/bin/whisper-server

stop() {
  pkill -f "whisper-server" 2>/dev/null || true
  pkill -f "parakeet_server.py" 2>/dev/null || true
  sleep 1
}
start_turbo()    { stop; nohup "$WS" -m "$NUC/models/ggml-large-v3-turbo-q5_0.bin" -l it --host 127.0.0.1 --port $PORT >"$NUC/stt.log" 2>&1 & echo "▶ Whisper large-v3-turbo"; }
start_small()    { stop; nohup "$WS" -m "$NUC/models/ggml-small-q5_1.bin"          -l it --host 127.0.0.1 --port $PORT >"$NUC/stt.log" 2>&1 & echo "▶ Whisper small (più veloce)"; }
start_parakeet() { stop; PATH=/opt/homebrew/bin:$PATH PK_PORT=$PORT nohup "$NUC/pk-venv/bin/python" "$NUC/parakeet_server.py" >"$NUC/stt.log" 2>&1 & echo "▶ Parakeet v3 (carica ~3s la prima volta)"; }

choice="${1:-}"
if [ -z "$choice" ]; then
  echo "── STT di Nuc — scegli il modello ──"
  echo "  1) Whisper large-v3-turbo  (accurato)"
  echo "  2) Whisper small           (più veloce)"
  echo "  3) Parakeet v3             (velocissimo, multilingua)"
  printf "Scelta [1/2/3]: "; read choice
fi
case "$choice" in
  1|turbo)    start_turbo ;;
  2|small)    start_small ;;
  3|parakeet) start_parakeet ;;
  *) echo "scelta non valida"; exit 1 ;;
esac
echo "Server STT in avvio su :$PORT — log: $NUC/stt.log"
echo "(attendi qualche secondo, poi parla a Nuc con: ./venv/bin/python hey_nuc.py)"
