#!/usr/bin/env python3
"""Persistent Parakeet STT server — drop-in for speech_to_text_server.py.

Compatible with the existing Unix-socket protocol used by speech_to_text_client.py
and key_listener.py — no client changes needed.

  request : {"audio_file": "<wav>"}\n     (legacy) or {"audio_path": "<wav>"}\n
  response: {"ok": true, "text": "...", "duration": <seconds>}\n  (or {"error": "..."})

Backend: NVIDIA Parakeet-TDT-0.6B-v3 (multilingual, incl. Italian) via onnx-asr +
onnxruntime-gpu on the GPU. Much faster than Whisper, comparable accuracy.

Deps (separate venv recommended):  pip install onnx-asr onnxruntime-gpu huggingface_hub
Env:
  STT_PARAKEET_MODEL    (default: nemo-parakeet-tdt-0.6b-v3)
  STT_PARAKEET_PROVIDER (default: CUDAExecutionProvider; use CPUExecutionProvider to test)
  STT_LLM_POSTPROCESS   (default: 1 — set to 0 to disable)
  STT_LLM_MODEL         (default: ~/models/stt-postprocess/qwen2.5-0.5b-instruct-q4_k_m.gguf)
  STT_LLM_GPU_LAYERS    (default: 99)
"""
import json, logging, os, signal, socket, tempfile, threading, time, wave

SOCKET_PATH = os.environ.get("STT_SOCKET", "/tmp/stt_server.sock")
MODEL_NAME  = os.environ.get("STT_PARAKEET_MODEL", "nemo-parakeet-tdt-0.6b-v3")
PROVIDER    = os.environ.get("STT_PARAKEET_PROVIDER", "CUDAExecutionProvider")
LLM_ENABLED = os.environ.get("STT_LLM_POSTPROCESS", "1").lower() in ("1", "true", "yes")
LLM_MODEL   = os.path.expanduser(os.environ.get(
    "STT_LLM_MODEL",
    "~/models/stt-postprocess/qwen2.5-0.5b-instruct-q4_k_m.gguf",
))
try:
    LLM_GPU_LAYERS = int(os.environ.get("STT_LLM_GPU_LAYERS", "99"))
except ValueError:
    LLM_GPU_LAYERS = 99
    logging.warning("STT_LLM_GPU_LAYERS is not a valid integer, defaulting to 99")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
SHUTDOWN = threading.Event()

_LLM_LOCK   = threading.Lock()
_MODEL_LOCK = threading.Lock()
_llm = None


def load_model():
    import onnx_asr
    logging.info(f"Loading Parakeet model: {MODEL_NAME} ({PROVIDER})")
    t0 = time.time()
    model = onnx_asr.load_model(MODEL_NAME, providers=[PROVIDER])
    logging.info(f"✅ Parakeet ready in {time.time() - t0:.1f}s")
    return model


def load_llm():
    global _llm
    if not LLM_ENABLED:
        return
    if not os.path.exists(LLM_MODEL):
        logging.warning(f"LLM model not found at {LLM_MODEL}, post-processing disabled")
        return
    try:
        from llama_cpp import Llama
        logging.info(f"Loading LLM for STT post-processing: {LLM_MODEL}")
        t0 = time.time()
        _llm = Llama(
            model_path=LLM_MODEL,
            n_gpu_layers=LLM_GPU_LAYERS,
            n_ctx=256,
            verbose=False,
        )
        logging.info(f"✅ LLM ready in {time.time() - t0:.1f}s")
    except Exception as e:
        logging.warning(f"LLM load failed, post-processing disabled: {e}")


def postprocess(text: str) -> str:
    if not _llm or not text:
        return text
    try:
        t0 = time.time()
        with _LLM_LOCK:
            result = _llm.create_chat_completion(
                messages=[
                    {"role": "system", "content": (
                        "You are a minimal transcription post-processor for Italian and English. "
                        "RULES — follow strictly:\n"
                        "1. If the text has no obvious errors, return it EXACTLY as-is, word for word.\n"
                        "2. Only fix a word if it is CLEARLY a speech-to-text mistake "
                        "(e.g. a garbled or impossible word). Never rephrase, never reorder, never substitute a correct word.\n"
                        "3. If the sentence starts with a question word (come, cosa, chi, dove, quando, perché, quale, quanto, "
                        "how, what, who, where, when, why, which) and does not end with '?', add '?'.\n"
                        "4. Return ONLY the text. No explanation, no commentary."
                    )},
                    {"role": "user", "content": text},
                ],
                max_tokens=256,
                temperature=0.0,
            )
        corrected = result["choices"][0]["message"]["content"].strip()
        elapsed = time.time() - t0
        if not corrected:
            return text
        # Safety: reject if word count changed by more than 20% (LLM rewrote instead of fixing)
        orig_words = len(text.split())
        corr_words = len(corrected.split())
        if orig_words > 0 and abs(corr_words - orig_words) / orig_words > 0.20:
            logging.warning(f"LLM in {elapsed:.2f}s: rejected rewrite ({orig_words}w→{corr_words}w), keeping original")
            return text
        if corrected != text:
            logging.info(f"LLM corrected in {elapsed:.2f}s: {repr(text)} → {repr(corrected)}")
        else:
            logging.info(f"LLM pass in {elapsed:.2f}s: no changes")
        return corrected
    except Exception as e:
        logging.warning(f"LLM post-processing failed: {e}")
        return text


def _pad_audio(audio_path: str, pad_ms: int = 300) -> str:
    """Append silence padding to avoid clipping the last word on key release.

    Returns a path to a temporary file (caller must delete it) or the original
    path on failure so the caller can always proceed.
    """
    try:
        with wave.open(audio_path, 'rb') as w:
            params = w.getparams()
            frames = w.readframes(w.getnframes())
        n_pad = int(params.framerate * pad_ms / 1000) * params.nchannels * params.sampwidth
        tmp = tempfile.NamedTemporaryFile(suffix=".padded.wav", delete=False, dir="/tmp")
        tmp.close()
        with wave.open(tmp.name, 'wb') as w:
            w.setparams(params)
            w.writeframes(frames + b'\x00' * n_pad)
        return tmp.name
    except Exception as e:
        logging.warning(f"Audio padding failed: {e}")
        return audio_path


def transcribe(model, audio_path: str) -> dict:
    if not os.path.exists(audio_path):
        return {"error": f"Audio file not found: {audio_path}"}
    padded = audio_path
    try:
        t0 = time.time()
        padded = _pad_audio(audio_path)
        with _MODEL_LOCK:
            text = (model.recognize(padded) or "").strip()
        elapsed = time.time() - t0
        logging.info(f"Transcribed in {elapsed:.2f}s: {text[:80]}{'…' if len(text) > 80 else ''}")
        text = postprocess(text)
        return {"ok": True, "text": text, "duration": elapsed}
    except Exception as e:
        logging.error(f"Transcription error: {e}")
        return {"error": str(e)}
    finally:
        if padded != audio_path:
            try:
                os.unlink(padded)
            except Exception:
                pass


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
        # Accept both "audio_path" (new) and "audio_file" (legacy client compat)
        audio_path = request.get("audio_path") or request.get("audio_file")
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
    load_llm()
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
        server.close()
        cleanup_socket()
        logging.info("Parakeet STT server stopped.")


if __name__ == "__main__":
    main()
