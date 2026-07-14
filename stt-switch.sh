#!/usr/bin/env bash
# Passa il dettato STT tra Parakeet e Nemotron (usano lo stesso socket /tmp/stt_server.sock).
# Richiede i due servizi systemd USER: parakeet-stt.service e nemotron-stt.service.
# Uso: ./stt-switch.sh nemotron | parakeet | status
set -euo pipefail
target="${1:-status}"
case "$target" in
  nemotron)
    systemctl --user disable --now parakeet-stt.service 2>/dev/null || true
    systemctl --user enable  --now nemotron-stt.service
    echo ">>> Attivo: NEMOTRON. Attendo il load..."; sleep 6 ;;
  parakeet)
    systemctl --user disable --now nemotron-stt.service 2>/dev/null || true
    systemctl --user enable  --now parakeet-stt.service
    echo ">>> Attivo: PARAKEET. Attendo il load..."; sleep 6 ;;
  status) : ;;
  *) echo "Uso: $0 nemotron|parakeet|status"; exit 1 ;;
esac
echo "--- stato ---"
echo "parakeet-stt: $(systemctl --user is-active parakeet-stt.service 2>/dev/null)"
echo "nemotron-stt: $(systemctl --user is-active nemotron-stt.service 2>/dev/null)"
ls -la /tmp/stt_server.sock 2>/dev/null || echo "(socket non presente)"
