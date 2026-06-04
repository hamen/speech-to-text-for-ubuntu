#!/usr/bin/env python3
"""Persistent Voxtral TTS server for Nuc (Apple Silicon / MLX).

Loads Mistral Voxtral-4B-TTS once, then on each request synthesizes Italian and
pitch-shifts it up (younger/cartoon Nuc voice) via sox.

  POST /tts  {"text": "..."}  ->  {"path": "/tmp/....wav"}   (server + client same Mac)

Env:
  VOX_VOICE  (default it_male)      Voxtral preset
  VOX_PITCH  (default 250)          sox pitch shift in cents (higher = younger)
  VOX_PORT   (default 8790)
"""
import os, tempfile, subprocess, wave
os.environ["PATH"] = "/opt/homebrew/bin:" + os.environ.get("PATH", "")  # sox
import numpy as np
from flask import Flask, request, jsonify
from mlx_audio.tts.utils import load

MODEL = os.environ.get("VOX_MODEL", "mlx-community/Voxtral-4B-TTS-2603-mlx-4bit")
VOICE = os.environ.get("VOX_VOICE", "it_male")
PITCH = os.environ.get("VOX_PITCH", "250")   # cents
PORT  = int(os.environ.get("VOX_PORT", "8790"))

print(f"[voxtral] loading {MODEL} …", flush=True)
model = load(MODEL)
print(f"[voxtral] ready on 127.0.0.1:{PORT} (voice={VOICE}, pitch={PITCH})", flush=True)

app = Flask(__name__)


def _write_wav(path, audio, sr):
    pcm = (np.clip(audio, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(pcm.tobytes())


@app.post("/tts")
def tts():
    text = (request.get_json(silent=True) or {}).get("text", "").strip()
    if not text:
        return jsonify(error="no text"), 400
    sr = 24000
    chunks = []
    for r in model.generate(text=text, voice=VOICE):
        chunks.append(np.array(r.audio, copy=False))
        sr = getattr(r, "sample_rate", sr)
    audio = np.concatenate(chunks).astype(np.float32) if len(chunks) > 1 else chunks[0].astype(np.float32)
    raw = tempfile.mktemp(suffix=".wav")
    out = tempfile.mktemp(suffix=".wav")
    _write_wav(raw, audio, sr)
    # pitch up for a younger Nuc voice (keeps tempo)
    subprocess.run(["sox", raw, out, "pitch", PITCH],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try: os.unlink(raw)
    except OSError: pass
    return jsonify(path=out)


if __name__ == "__main__":
    app.run("127.0.0.1", PORT, threaded=False)
