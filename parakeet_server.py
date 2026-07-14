#!/usr/bin/env python3
"""Persistent Parakeet-v3 STT server (Apple Silicon / MLX).

POST /inference  (multipart form field 'file' = wav)  ->  {"text": "..."}
Drop-in compatible with whisper.cpp's /inference, so hey_nuc.py (STT_MODE=
whispercpp) needs no changes — point it at this server's port instead.

Run in the parakeet venv:  PK_PORT=8089 ~/nuc/pk-venv/bin/python parakeet_server.py
"""
import os, tempfile, wave
os.environ["PATH"] = "/opt/homebrew/bin:" + os.environ.get("PATH", "")  # ffmpeg (fallback)
import numpy as np
import mlx.core as mx
import parakeet_mlx
import parakeet_mlx.audio as _pkaudio
import parakeet_mlx.parakeet as _pkmod
from flask import Flask, request, jsonify

# Skip the ffmpeg round-trip: hey_nuc sends a 16 kHz mono s16 wav already, so read
# it directly (same mx.array load_audio would return). Falls back to ffmpeg otherwise.
_orig_load_audio = _pkaudio.load_audio
def _fast_load_audio(filename, sampling_rate, dtype=mx.bfloat16):
    try:
        with wave.open(str(filename), "rb") as w:
            if w.getnchannels() == 1 and w.getsampwidth() == 2 and w.getframerate() == sampling_rate:
                pcm = w.readframes(w.getnframes())
                return mx.array(np.frombuffer(pcm, dtype=np.int16)).astype(mx.float32) / 32768.0
    except Exception:
        pass
    return _orig_load_audio(filename, sampling_rate, dtype)
_pkaudio.load_audio = _fast_load_audio
_pkmod.load_audio = _fast_load_audio   # transcribe() resolves the name in this namespace

MODEL = os.environ.get("PK_MODEL", "mlx-community/parakeet-tdt-0.6b-v3")
PORT  = int(os.environ.get("PK_PORT", "8089"))

print(f"[parakeet] loading {MODEL} …", flush=True)
model = parakeet_mlx.from_pretrained(MODEL)
print(f"[parakeet] ready on 127.0.0.1:{PORT}", flush=True)

app = Flask(__name__)

@app.post("/inference")
def inference():
    f = request.files.get("file")
    if not f:
        return jsonify(error="no file"), 400
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as t:
        f.save(t.name); path = t.name
    try:
        text = model.transcribe(path).text
    finally:
        try: os.unlink(path)
        except OSError: pass
    return jsonify(text=text)

if __name__ == "__main__":
    # parakeet-mlx model is not thread-safe → serialize requests (fine for 1 user)
    app.run("127.0.0.1", PORT, threaded=False)
