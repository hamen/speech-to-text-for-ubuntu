#!/usr/bin/env python3
"""Persistent Parakeet-v3 STT server (Apple Silicon / MLX).

POST /inference  (multipart form field 'file' = wav)  ->  {"text": "..."}
Drop-in compatible with whisper.cpp's /inference, so hey_nuc.py (STT_MODE=
whispercpp) needs no changes — point it at this server's port instead.

Run in the parakeet venv:  PK_PORT=8089 ~/nuc/pk-venv/bin/python parakeet_server.py
"""
import os, tempfile
os.environ["PATH"] = "/opt/homebrew/bin:" + os.environ.get("PATH", "")  # ffmpeg
import parakeet_mlx
from flask import Flask, request, jsonify

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
