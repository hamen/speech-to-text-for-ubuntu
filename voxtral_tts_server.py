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

SR = 24000
# Younger Nuc voice for FREE via playback rate: telling sox a higher input rate
# raises pitch (~+PITCH cents) and shortens the clip a bit — and it streams, so
# no pitch post-processing that would block. First audio comes out in ~0.8s.
PLAY_RATE = int(round(SR * (2 ** (float(PITCH) / 1200.0))))


@app.post("/tts")
def tts():
    text = (request.get_json(silent=True) or {}).get("text", "").strip()
    if not text:
        return jsonify(error="no text"), 400
    # stream Voxtral chunks straight to sox, played at the elevated rate
    player = subprocess.Popen(
        ["sox", "-q", "-t", "raw", "-r", str(PLAY_RATE), "-e", "float", "-b", "32",
         "-c", "1", "-", "-d"],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for r in model.generate(text=text, voice=VOICE, stream=True, streaming_interval=0.4):
            player.stdin.write(np.asarray(r.audio, dtype=np.float32).tobytes())
        player.stdin.close()
        player.wait()
    except Exception as e:
        try: player.kill()
        except Exception: pass
        return jsonify(error=str(e)), 500
    return jsonify(ok=True)


if __name__ == "__main__":
    app.run("127.0.0.1", PORT, threaded=False)
