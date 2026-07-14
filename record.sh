#!/usr/bin/env bash
# Registra audio dal microfono di default PipeWire (16kHz mono s16 WAV).
# Uso: ./record.sh [secondi] [output.wav]
set -euo pipefail
SECS="${1:-6}"
OUT="${2:-./sample.wav}"
echo ">>> Parla ora per ${SECS}s..."
timeout "${SECS}" pw-record --rate 16000 --channels 1 --format s16 "$OUT" || true
echo ">>> Salvato: $OUT"
ls -la "$OUT"
