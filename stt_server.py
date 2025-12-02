#!/usr/bin/env python3
"""
Persistent Speech-to-Text Server

Keeps the Whisper model loaded in memory and handles transcription requests
via a Unix socket. This eliminates the ~2 second model loading time for each request.

Usage:
    # Start server (usually via menu.sh)
    python3 stt_server.py

    # The server listens on /tmp/stt_server.sock
    # speech_to_text.py automatically connects to this server when available

Environment variables (same as speech_to_text.py):
    STT_MODEL: Model name (default: large-v3)
    STT_DEVICE: Device to use (default: cuda)
    STT_COMPUTE_TYPE: Compute type (default: float16 for GPU, int8 for CPU)
    STT_LANGUAGE: Language code or 'auto' (default: auto)
"""

import json
import logging
import os
import signal
import socket
import sys
import threading
import time
from pathlib import Path

# Setup logging
REPO_DIR = os.path.dirname(os.path.realpath(__file__))
log_file = os.path.join(REPO_DIR, 'log', 'stt_server.log')
os.makedirs(os.path.dirname(log_file), exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s: %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(log_file)
    ]
)

SOCKET_PATH = "/tmp/stt_server.sock"
SHUTDOWN_FLAG = threading.Event()


def load_model():
    """Load the Whisper model once and return it."""
    try:
        from faster_whisper import WhisperModel
        
        model_name = os.environ.get("STT_MODEL", "large-v3")
        device = os.environ.get("STT_DEVICE", "cuda")
        compute_type = os.environ.get(
            "STT_COMPUTE_TYPE",
            "float16" if device != "cpu" else "int8",
        )
        
        logging.info(f"Loading Whisper model: name={model_name} device={device} compute_type={compute_type}")
        logging.info("This may take a moment...")
        
        start = time.time()
        model = WhisperModel(model_name, device=device, compute_type=compute_type)
        elapsed = time.time() - start
        
        logging.info(f"✅ Model loaded in {elapsed:.1f}s - ready for transcription requests")
        return model
        
    except Exception as e:
        logging.error(f"Failed to load model: {e}")
        sys.exit(1)


def transcribe(model, audio_path: str) -> dict:
    """Transcribe audio file using the pre-loaded model."""
    import numpy as np
    import soundfile as sf
    
    try:
        # Load audio
        if not os.path.exists(audio_path):
            return {"error": f"Audio file not found: {audio_path}"}
        
        audio, samplerate = sf.read(audio_path)
        audio = audio.astype('float32')
        
        # Convert stereo to mono if necessary
        if len(audio.shape) > 1 and audio.shape[1] > 1:
            audio = np.mean(audio, axis=1)
        
        # Get transcription settings from environment
        beam_size = int(os.environ.get("STT_BEAM_SIZE", "1"))
        vad_filter = os.environ.get("STT_VAD", "1").lower() in ("1", "true", "yes")
        language_raw = os.environ.get("STT_LANGUAGE", "auto")
        language = None if language_raw.lower() in ("auto", "", "none") else language_raw
        condition = os.environ.get("STT_CONDITION", "1").lower() in ("1", "true", "yes")
        temperature = float(os.environ.get("STT_TEMPERATURE", "0.0"))
        
        # Transcribe
        start = time.time()
        segments, info = model.transcribe(
            audio,
            language=language,
            beam_size=beam_size,
            vad_filter=vad_filter,
            condition_on_previous_text=condition,
            temperature=temperature,
            task="transcribe",
        )
        
        # Collect results
        results = []
        for seg in segments:
            text = seg.text.strip()
            if text:
                results.append(text)
        
        elapsed = time.time() - start
        full_text = " ".join(results).strip()
        
        logging.info(f"Transcribed in {elapsed:.2f}s: {full_text[:80]}{'...' if len(full_text) > 80 else ''}")
        
        return {
            "text": full_text,
            "language": info.language if hasattr(info, 'language') else None,
            "language_probability": info.language_probability if hasattr(info, 'language_probability') else None,
            "duration": elapsed,
            "segments": len(results)
        }
        
    except Exception as e:
        logging.error(f"Transcription error: {e}")
        return {"error": str(e)}


def handle_client(conn, model):
    """Handle a single client connection."""
    try:
        # Receive the request (audio file path)
        data = b""
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
            # Check for end of message (newline)
            if b"\n" in data:
                break
        
        if not data:
            return
        
        request = json.loads(data.decode('utf-8').strip())
        audio_path = request.get("audio_path")
        
        if not audio_path:
            response = {"error": "No audio_path provided"}
        else:
            logging.info(f"Processing: {audio_path}")
            response = transcribe(model, audio_path)
        
        # Send response
        conn.sendall((json.dumps(response) + "\n").encode('utf-8'))
        
    except json.JSONDecodeError as e:
        logging.error(f"Invalid JSON request: {e}")
        try:
            conn.sendall((json.dumps({"error": "Invalid JSON"}) + "\n").encode('utf-8'))
        except:
            pass
    except Exception as e:
        logging.error(f"Client handler error: {e}")
    finally:
        conn.close()


def cleanup_socket():
    """Remove the socket file if it exists."""
    try:
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
    except Exception as e:
        logging.warning(f"Could not remove socket: {e}")


def signal_handler(signum, frame):
    """Handle shutdown signals."""
    logging.info(f"Received signal {signum}, shutting down...")
    SHUTDOWN_FLAG.set()


def main():
    """Main server loop."""
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Clean up any existing socket
    cleanup_socket()
    
    # Load the model once
    model = load_model()
    
    # Create Unix socket
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(SOCKET_PATH)
    server.listen(5)
    server.settimeout(1.0)  # Allow checking shutdown flag
    
    # Make socket accessible to all users (needed when running as root)
    os.chmod(SOCKET_PATH, 0o666)
    
    logging.info(f"🎤 STT Server listening on {SOCKET_PATH}")
    logging.info("   Send transcription requests via speech_to_text.py")
    logging.info("   Press Ctrl+C to stop")
    
    try:
        while not SHUTDOWN_FLAG.is_set():
            try:
                conn, _ = server.accept()
                # Handle each client in a thread to allow concurrent requests
                thread = threading.Thread(target=handle_client, args=(conn, model))
                thread.daemon = True
                thread.start()
            except socket.timeout:
                continue
            except Exception as e:
                if not SHUTDOWN_FLAG.is_set():
                    logging.error(f"Accept error: {e}")
    finally:
        logging.info("Shutting down server...")
        server.close()
        cleanup_socket()
        logging.info("Server stopped")


if __name__ == "__main__":
    main()

