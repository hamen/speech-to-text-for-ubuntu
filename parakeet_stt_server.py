#!/usr/bin/env python3
"""Persistent Parakeet STT server — drop-in for stt_server.py.

Speaks the EXACT same Unix-socket protocol as stt_server.py, so key_listener.py
and speech_to_text.py need ZERO changes: the menu just starts this server instead
of the Whisper one.

  request : {"audio_path": "<wav>"}\n     (16 kHz mono wav, as key_listener records)
  response: {"text": "...", "duration": <seconds>}\n   (or {"error": "..."})

Backend: NVIDIA Parakeet-TDT-0.6B-v3 (multilingual, incl. Italian) via onnx-asr +
onnxruntime-gpu on the GPU. Much faster than Whisper, comparable accuracy.

Deps (separate venv recommended):  pip install onnx-asr onnxruntime-gpu huggingface_hub
Env:
  STT_PARAKEET_MODEL  (default: nemo-parakeet-tdt-0.6b-v3)
  STT_PARAKEET_PROVIDER (default: CUDAExecutionProvider; use CPUExecutionProvider to test)
"""
import json, logging, os, signal, socket, threading, time

SOCKET_PATH = os.environ.get("STT_SOCKET", "/tmp/stt_server.sock")
MODEL_NAME  = os.environ.get("STT_PARAKEET_MODEL", "nemo-parakeet-tdt-0.6b-v3")
PROVIDER    = os.environ.get("STT_PARAKEET_PROVIDER", "CUDAExecutionProvider")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
SHUTDOWN = threading.Event()


def load_model():
    import onnx_asr
    logging.info(f"Loading Parakeet model: {MODEL_NAME} ({PROVIDER})")
    t0 = time.time()
    model = onnx_asr.load_model(MODEL_NAME, providers=[PROVIDER])
    logging.info(f"✅ Parakeet ready in {time.time() - t0:.1f}s")
    return model


def transcribe(model, audio_path: str) -> dict:
    if not os.path.exists(audio_path):
        return {"error": f"Audio file not found: {audio_path}"}
    try:
        t0 = time.time()
        text = (model.recognize(audio_path) or "").strip()
        elapsed = time.time() - t0
        logging.info(f"Transcribed in {elapsed:.2f}s: {text[:80]}{'…' if len(text) > 80 else ''}")
        return {"text": text, "duration": elapsed}
    except Exception as e:
        logging.error(f"Transcription error: {e}")
        return {"error": str(e)}


def handle_client(conn, model):
    try:
        data = b""
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
            if b"\n" in data:
                break
        if not data:
            return
        request = json.loads(data.decode("utf-8").strip())
        audio_path = request.get("audio_path")
        response = transcribe(model, audio_path) if audio_path else {"error": "No audio_path provided"}
        conn.sendall((json.dumps(response) + "\n").encode("utf-8"))
    except json.JSONDecodeError:
        try: conn.sendall((json.dumps({"error": "Invalid JSON"}) + "\n").encode("utf-8"))
        except Exception: pass
    except Exception as e:
        logging.error(f"Client handler error: {e}")
    finally:
        conn.close()


def cleanup_socket():
    try:
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
    except Exception as e:
        logging.warning(f"Could not remove socket: {e}")


def main():
    signal.signal(signal.SIGINT, lambda *_: SHUTDOWN.set())
    signal.signal(signal.SIGTERM, lambda *_: SHUTDOWN.set())
    cleanup_socket()
    model = load_model()
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(SOCKET_PATH)
    server.listen(5)
    server.settimeout(1.0)
    os.chmod(SOCKET_PATH, 0o666)  # accessible to user clients when run as root
    logging.info(f"🐙 Parakeet STT Server listening on {SOCKET_PATH}")
    try:
        while not SHUTDOWN.is_set():
            try:
                conn, _ = server.accept()
                t = threading.Thread(target=handle_client, args=(conn, model), daemon=True)
                t.start()
            except socket.timeout:
                continue
    finally:
        cleanup_socket()
        logging.info("Parakeet STT server stopped.")


if __name__ == "__main__":
    main()
