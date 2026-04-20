#!/usr/bin/env python3
"""
OpenAI-compatible HTTP API for the local STT server.

Exposes POST /v1/audio/transcriptions (OpenAI Whisper API format)
and proxies requests to the existing Unix socket STT server.

Usage:
    python3 stt_api.py
    # or: uvicorn stt_api:app --host 0.0.0.0 --port 8787

Then set:
    export OPENAI_WHISPER_BASE_URL=http://localhost:8787/v1

Requires: pip install fastapi uvicorn python-multipart
"""

import json
import logging
import os
import socket
import tempfile
import time

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s",
)

SOCKET_PATH = "/tmp/stt_server.sock"
PORT = int(os.environ.get("STT_API_PORT", "8787"))

app = FastAPI(title="Local Whisper API", description="OpenAI-compatible wrapper for faster-whisper on GPU")


def transcribe_via_socket(audio_path: str) -> dict:
    """Send transcription request to the Unix socket STT server."""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(300)  # 5 min for long audio
    try:
        sock.connect(SOCKET_PATH)
        request = json.dumps({"audio_path": audio_path}) + "\n"
        sock.sendall(request.encode("utf-8"))

        data = b""
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            data += chunk
            if b"\n" in data:
                break

        return json.loads(data.decode("utf-8").strip())
    finally:
        sock.close()


@app.get("/v1/models")
async def list_models():
    """List available models (for compatibility)."""
    return {
        "object": "list",
        "data": [
            {
                "id": "whisper-large-v3",
                "object": "model",
                "owned_by": "local",
            }
        ],
    }


@app.post("/v1/audio/transcriptions")
async def transcribe(
    file: UploadFile = File(...),
    model: str = Form("whisper-large-v3"),
    language: str = Form(None),
    response_format: str = Form("json"),
    temperature: float = Form(0.0),
):
    """OpenAI-compatible transcription endpoint."""
    # Check STT server is running
    if not os.path.exists(SOCKET_PATH):
        return JSONResponse(
            status_code=503,
            content={"error": {"message": "STT server not running (no socket at /tmp/stt_server.sock)", "type": "server_error"}},
        )

    # Save uploaded audio to temp file
    suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir="/tmp") as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        start = time.time()
        result = transcribe_via_socket(tmp_path)
        elapsed = time.time() - start

        if "error" in result:
            return JSONResponse(status_code=500, content={"error": {"message": result["error"], "type": "transcription_error"}})

        text = result.get("text", "")
        logging.info(f"Transcribed in {elapsed:.2f}s ({len(text)} chars)")

        # Return in requested format
        if response_format == "text":
            from fastapi.responses import PlainTextResponse
            return PlainTextResponse(text)
        elif response_format == "verbose_json":
            return {
                "task": "transcribe",
                "language": result.get("language", "unknown"),
                "duration": result.get("duration", elapsed),
                "text": text,
            }
        else:
            # Standard json format (OpenAI default)
            return {"text": text}
    finally:
        os.unlink(tmp_path)


@app.get("/health")
async def health():
    """Health check."""
    socket_ok = os.path.exists(SOCKET_PATH)
    return {"status": "ok" if socket_ok else "degraded", "stt_server": "connected" if socket_ok else "not running"}


if __name__ == "__main__":
    import uvicorn
    logging.info(f"Starting OpenAI-compatible Whisper API on port {PORT}")
    logging.info(f"Set OPENAI_WHISPER_BASE_URL=http://localhost:{PORT}/v1")
    uvicorn.run(app, host="0.0.0.0", port=PORT)
