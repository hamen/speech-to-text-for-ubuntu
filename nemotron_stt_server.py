#!/usr/bin/env python3
"""Persistent Nemotron 3.5 ASR STT server (the only STT engine).

Parla lo STESSO protocollo Unix-socket di key_listener.py / speech_to_text.py:
  request : {"audio_path": "<wav>"}\n   (o "audio_file", compat legacy)
  response: {"ok": true, "text": "...", "duration": <s>}\n   (o {"error": "..."})

Backend: nvidia/nemotron-3.5-asr-streaming-0.6b via transformers>=5.13 (bf16, CUDA).
Per-utterance offline (model.generate). Lingua via STT_LANG (default "auto":
rilevamento automatico, gestisce il dettato misto italiano/inglese).

Env:
  STT_SOCKET   (default /tmp/stt_server.sock)  — stesso socket del client esistente
  STT_LANG     (default auto; usa un locale es. it-IT per forzare una lingua)
  STT_DTYPE    (default bfloat16; usa float32 per fallback)
  STT_PAD_MS   (default 300)  — padding di silenzio anti-taglio ultima parola
"""
import json, logging, os, signal, socket, threading, time
import numpy as np

SOCKET_PATH = os.environ.get("STT_SOCKET", "/tmp/stt_server.sock")
LANG        = os.environ.get("STT_LANG", "auto")
DTYPE_NAME  = os.environ.get("STT_DTYPE", "bfloat16")
try:
    PAD_MS = int(os.environ.get("STT_PAD_MS", "300"))
except ValueError:
    PAD_MS = 300
MODEL_ID = "nvidia/nemotron-3.5-asr-streaming-0.6b"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
SHUTDOWN = threading.Event()
_MODEL_LOCK = threading.Lock()

_model = None
_processor = None
_torch = None
_load_audio = None
_dtype = None
_sr = 16000


def load_model():
    global _model, _processor, _torch, _load_audio, _dtype, _sr
    import torch
    from transformers import AutoModelForRNNT, AutoProcessor
    from transformers.audio_utils import load_audio
    _torch = torch
    _load_audio = load_audio
    _dtype = getattr(torch, DTYPE_NAME, torch.bfloat16)
    logging.info(f"Loading Nemotron 3.5 ASR: {MODEL_ID} (dtype={_dtype}, lang={LANG})")
    t0 = time.time()
    _processor = AutoProcessor.from_pretrained(MODEL_ID)
    _model = AutoModelForRNNT.from_pretrained(MODEL_ID, dtype=_dtype, device_map="auto")
    _model.eval()
    _sr = _processor.feature_extractor.sampling_rate
    logging.info(f"✅ Nemotron ready in {time.time()-t0:.1f}s on {_model.device}")


MAX_REQUEST_BYTES = 65536          # richiesta JSON: cap anti-OOM su recv non terminato
MAX_AUDIO_BYTES   = 200 * 1024 * 1024  # ~200MB: rifiuta file enormi / FIFO infinite


def transcribe(audio_path: str) -> dict:
    if not os.path.isfile(audio_path):
        return {"error": f"Audio file not found or not a regular file: {audio_path}"}
    if os.path.getsize(audio_path) > MAX_AUDIO_BYTES:
        return {"error": "Audio file too large"}
    try:
        t0 = time.time()
        audio = _load_audio(audio_path, sampling_rate=_sr)
        if PAD_MS > 0:
            audio = np.concatenate([audio, np.zeros(int(_sr * PAD_MS / 1000), dtype=audio.dtype)])
        inputs = _processor(audio, sampling_rate=_sr, language=LANG, return_tensors="pt")
        inputs = inputs.to(_model.device, dtype=_model.dtype)
        with _MODEL_LOCK, _torch.no_grad():
            out = _model.generate(**inputs, return_dict_in_generate=True)
        decoded = _processor.decode(out.sequences, skip_special_tokens=True)
        if isinstance(decoded, (list, tuple)):
            decoded = decoded[0] if decoded else ""
        text = decoded.strip()
        elapsed = time.time() - t0
        logging.info(f"Transcribed in {elapsed:.2f}s: {text[:80]}{'…' if len(text) > 80 else ''}")
        return {"ok": True, "text": text, "duration": elapsed}
    except Exception as e:
        logging.error(f"Transcription error: {e}")
        return {"error": str(e)}


def handle_client(conn):
    try:
        conn.settimeout(5.0)  # niente slowloris: client lento => chiudi
        data = b""
        while b"\n" not in data:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
            if len(data) > MAX_REQUEST_BYTES:
                try: conn.sendall((json.dumps({"error": "Request too large"}) + "\n").encode("utf-8"))
                except Exception: pass
                return
        if not data:
            return
        request = json.loads(data.decode("utf-8").strip())
        audio_path = request.get("audio_path") or request.get("audio_file")
        response = transcribe(audio_path) if audio_path else {"error": "No audio_path provided"}
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
    load_model()
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(SOCKET_PATH)
    server.listen(5)
    server.settimeout(1.0)
    os.chmod(SOCKET_PATH, 0o666)  # socket usable by both root and non-root clients
    logging.info(f"🐙 Nemotron STT Server listening on {SOCKET_PATH}")
    try:
        while not SHUTDOWN.is_set():
            try:
                conn, _ = server.accept()
                threading.Thread(target=handle_client, args=(conn,), daemon=True).start()
            except socket.timeout:
                continue
    finally:
        server.close()
        cleanup_socket()
        logging.info("Nemotron STT server stopped.")


if __name__ == "__main__":
    main()
