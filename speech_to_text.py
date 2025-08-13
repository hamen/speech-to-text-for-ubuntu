#!/usr/bin/env python3
"""
Simple speech-to-text processor using Faster Whisper. For speed we use the tiny.en model.

The script expects an audio file (e.g. /tmp/recorded_audio.wav) as an argument.

Usage: python3 speech_to_text.py <audio_file>

Tested on Ubuntu 24.04.2 LTS

The script is intended to be run using your Python virtual environment (see key_listener.py).
"""

import logging
import sys
import os
import pwd
import shutil
import subprocess
import shlex

OUTPUT_FILE = "/tmp/speech_to_text_output.txt"
TYPE_SUCCESS_FILE = "/tmp/speech_to_text_typed.ok"


# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s: %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/tmp/speech_to_text.log')
    ]
)

try:
    import numpy as np
    import soundfile as sf
    from faster_whisper import WhisperModel
except ImportError as e:
    print(f"Error: Required library not found: {e}")
    print("Install in your venv with: pip install numpy pyautogui soundfile faster-whisper")
    sys.exit(1)

def log_user_info():
    """Log current user information."""
    try:
        uid = os.geteuid()
        user = pwd.getpwuid(uid).pw_name
        logging.info(f"Running as user: {os.getlogin()}")
        logging.info(f"Effective user: {user} (UID: {uid})")
    except Exception as e:
        logging.warning(f"Could not determine user info: {e}")

def load_audio(file_path):
    """Load and preprocess audio file."""
    if not os.path.exists(file_path):
        logging.error(f"Audio file not found: {file_path}")
        sys.exit(1)

    try:
        audio, samplerate = sf.read(file_path)
        audio = audio.astype('float32')

        # Convert stereo to mono if necessary
        if len(audio.shape) > 1 and audio.shape[1] > 1:
            audio = np.mean(audio, axis=1)
            logging.info("Converted stereo audio to mono")

        logging.info(f"Audio loaded: {file_path}, sample rate: {samplerate}")
        return audio

    except Exception as e:
        logging.error(f"Failed to read audio file {file_path}: {e}")
        sys.exit(1)

def transcribe_audio(audio):
    """Transcribe audio using Whisper."""
    try:
        model_name = os.environ.get("STT_MODEL", "tiny.en")
        device = os.environ.get("STT_DEVICE", "cpu")
        compute_type = os.environ.get(
            "STT_COMPUTE_TYPE",
            "float16" if device != "cpu" else "int8",
        )
        logging.info(
            f"Loading Whisper model: name={model_name} device={device} compute_type={compute_type}"
        )
        model = WhisperModel(model_name, device=device, compute_type=compute_type)

        logging.info("Starting transcription...")
        beam_size = int(os.environ.get("STT_BEAM_SIZE", "1"))
        vad_filter = os.environ.get("STT_VAD", "1").lower() in ("1", "true", "yes")
        language_raw = os.environ.get("STT_LANGUAGE", "en")
        language = None if language_raw.lower() in ("auto", "", "none") else language_raw
        condition = os.environ.get("STT_CONDITION", "1").lower() in ("1", "true", "yes")
        temperature = float(os.environ.get("STT_TEMPERATURE", "0.0"))
        segments, _ = model.transcribe(
            audio,
            language=language,
            beam_size=beam_size,
            vad_filter=vad_filter,
            condition_on_previous_text=condition,
            temperature=temperature,
            task="transcribe",
        )

        # Process segments
        results = []
        for seg in segments:
            text = seg.text.strip()
            if text:
                results.append(text)
                logging.info(f"Recognized: {text}")

        logging.info(f"Transcription completed: {len(results)} segments")
        return results

    except Exception as e:
        logging.error(f"Transcription failed: {e}")
        sys.exit(1)

def _type_with_wtype(text: str) -> bool:
    """Try to type using wtype (Wayland). Returns True if succeeded."""
    if not shutil.which("wtype"):
        return False
    try:
        # wtype prints nothing on success
        subprocess.run(["wtype", text + " "], check=True)
        return True
    except Exception as e:
        logging.error(f"wtype failed: {e}")
        return False

def _type_with_ydotool(text: str) -> bool:
    """Try to type using ydotool (Wayland). Returns True if succeeded."""
    if not shutil.which("ydotool"):
        return False

def _mark_type_success() -> None:
    try:
        with open(TYPE_SUCCESS_FILE, "w", encoding="utf-8"):
            pass
    except Exception:
        pass
    # ydotool usually requires root unless ydotoold is running
    is_root = False
    try:
        is_root = os.geteuid() == 0
    except Exception:
        pass
    ydotoold_running = False
    try:
        subprocess.check_call(["pgrep", "-x", "ydotoold"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        ydotoold_running = True
    except Exception:
        ydotoold_running = False
    if not is_root and not ydotoold_running:
        return False
    try:
        # ydotool type automatically appends newline only with -k; we avoid it.
        subprocess.run(["ydotool", "type", text + " "], check=True)
        return True
    except Exception as e:
        logging.error(f"ydotool failed: {e}")
        return False

def type_text(text):
    """Type text using pyautogui (imported lazily), falling back to wtype on Wayland."""
    # On GNOME Wayland, simulated typing is often blocked. Ensure clipboard is set first.
    if os.environ.get("XDG_SESSION_TYPE", "").lower() == "wayland" and "GNOME" in os.environ.get("XDG_CURRENT_DESKTOP", ""):
        if _copy_to_clipboard(text + " "):
            _notify("Speech-to-Text", "Transcription copied. Press Ctrl+V to paste.")
    try:
        import pyautogui  # Lazy import to avoid X display issues on Wayland during module import
        logging.info(f"Typing: {text}")
        pyautogui.typewrite(text + ' ')
        _mark_type_success()
        return
    except Exception as e:
        logging.warning(f"pyautogui typing failed: {e}")
    # Fallback for Wayland
    if _type_with_wtype(text) or _type_with_ydotool(text):
        _mark_type_success()
        return
    # Final fallback: put text in clipboard and notify the user to paste
    if _copy_to_clipboard(text + " "):
        _notify("Speech-to-Text", "Text copied to clipboard. Press Ctrl+V to paste.")
        return
    logging.error("No available method to type text. Install 'wtype' on Wayland or use an Xorg session.")

def _copy_to_clipboard(text: str) -> bool:
    """Copy text to clipboard using wl-copy (Wayland) or xclip/xsel (X11)."""
    try:
        if shutil.which("wl-copy"):
            p = subprocess.run(["wl-copy"], input=text.encode("utf-8"), check=True)
            return p.returncode == 0
        if shutil.which("xclip"):
            p = subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode("utf-8"), check=True)
            return p.returncode == 0
        if shutil.which("xsel"):
            p = subprocess.run(["xsel", "--clipboard", "--input"], input=text.encode("utf-8"), check=True)
            return p.returncode == 0
    except Exception as e:
        logging.error(f"Failed to copy to clipboard: {e}")
    return False

def _notify(title: str, message: str) -> None:
    """Send a desktop notification if notify-send is available."""
    if not shutil.which("notify-send"):
        return
    try:
        subprocess.run(["notify-send", title, message], check=False)
    except Exception:
        pass

def write_output_file(text: str, path: str = OUTPUT_FILE) -> None:
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        logging.info(f"Saved transcription to {path}")
    except Exception as e:
        logging.error(f"Failed to write transcription file: {e}")

def main():
    """Main function."""
    # Check arguments
    if len(sys.argv) < 2:
        print("Usage: python speech_to_text.py <audio_file>")
        sys.exit(1)

    audio_file = sys.argv[1]

    # Log user info
    log_user_info()

    # Process audio
    logging.info(f"Processing audio file: {audio_file}")

    # Load audio
    audio = load_audio(audio_file)

    # Transcribe
    segments = transcribe_audio(audio)

    # Combine segments into one text line
    full_text = " ".join(segments).strip()
    if not full_text:
        logging.info("No text recognized")
        return

    # Always write to output file for downstream consumers (e.g., root ydotool typer)
    write_output_file(full_text)

    # Optionally type (skip if instructed by environment)
    if os.environ.get("STT_NO_TYPE"):
        logging.info("Skipping typing (STT_NO_TYPE set)")
        return

    # Type results
    type_text(full_text)

    logging.info("Processing completed")

if __name__ == "__main__":
    main()

