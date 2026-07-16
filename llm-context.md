# Speech-to-Text for Ubuntu - LLM Context

## App Name & Purpose
**Speech-to-Text for Ubuntu** - A powerful push-to-talk speech recognition system that provides offline transcription using the **NVIDIA Nemotron 3.5 ASR** model with **GPU acceleration**, **intelligent text cleaning**, **persistent model server**, and multiple output modes. Optimized for NVIDIA RTX 4070 and other CUDA GPUs.

## Platform & Environment
- **OS**: Ubuntu 24.04.2 LTS (Linux)
- **Python**: 3.x with virtual environment
- **Desktop**: Wayland/X11 compatible
- **Architecture**: x86_64 with **NVIDIA RTX 4070 GPU acceleration**
- **CUDA**: 12.x with cuDNN for GPU inference
- **Languages**: 99 languages supported with automatic detection

## How It Works (High-Level)
1. **Push-to-Talk Recording**: User triggers recording via one of multiple methods:
   - **Native Double-Tap**: Double-tap and hold **Left Control**. **Left Super** is optional and disabled by default via config.
   - **Legacy Hotkey**: Press and hold **F16** (often remapped from a mouse button).
2. **Input Detection**: The system listens on **all connected keyboards** simultaneously, ensuring robust detection regardless of remapping tools.
3. **Audio Processing**: System records audio using `pw-record` (PipeWire) or `arecord` (ALSA).
4. **⚡ Instant Transcription**: Audio is sent to the **persistent Nemotron STT server** which keeps the model in memory, so transcription is near-instant (no per-call model load).
5. **Intelligent Text Cleaning**: Transcribed text is automatically cleaned to remove speech artifacts while preserving meaningful content.
6. **Output Modes**: User can choose between automatic typing or clipboard + notification.

## Architecture
```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────────┐
│  key_listener   │────▶│ speech_to_text   │────▶│  nemotron_stt_server │
│  (detects keys) │     │ (processes audio)│     │    (model in RAM)    │
└─────────────────┘     └──────────────────┘     └──────────────────────┘
                              │   Unix Socket: /tmp/stt_server.sock
```
- **nemotron_stt_server.py** loads the Nemotron model once and keeps it in memory; it is run as the systemd user service `nemotron-stt`.
- **speech_to_text.py** connects to the server over the Unix socket (no local fallback).

## Key Files & Their Purpose

### Core Scripts
- **`key_listener.py`** - Main orchestrator: listens for native hotkeys (Ctrl/Super) and legacy F16 across all devices, records audio, calls speech processing.
- **`speech_to_text.py`** - Audio processor: loads audio, connects to STT server for transcription, handles output modes, applies intelligent text cleaning.
- **`nemotron_stt_server.py`** - **Persistent model server**: keeps the Nemotron model in memory, handles transcription requests via the Unix socket for instant response. Run as the systemd user service `nemotron-stt`.
- **`menu.sh`** - Interactive interface using [Gum](https://github.com/charmbracelet/gum) for setup and management (legacy; the server is normally managed by systemd).

### Configuration & Logs
- **`log/`** - Dedicated directory for all system logs (gitignored).
- **`.gitignore`** - Prevents logs, temp files, and build artifacts from being committed.
- **`requirements.txt`** - Python dependencies for the virtual environment.

## Defaults & Paths
- **Native Shortcuts**: Double-Tap Left Control (Hold). Double-Tap Left Super (Hold) is available but disabled by default.
- **Legacy Hotkey**: F16 (remapped from Ctrl+Alt+F12 or Ctrl+Shift+F12 via input-remapper)
- **Input Remapper Config**: `~/.config/input-remapper/presets/ctrl-alt-f12-to-f16.json`
- **STT Server Socket**: `/tmp/stt_server.sock`
- **Audio File**: `/tmp/recorded_audio.wav`
- **Log Files**: `log/key_listener.log`, `log/speech_to_text.log`; server logs via `journalctl --user -u nemotron-stt`
- **Output File**: `/tmp/speech_to_text_output.txt`
- **Python Venv**: `venv/bin/python3`
- **Model**: NVIDIA Nemotron 3.5 ASR (~2.5GB in cache)
- **GPU Device**: cuda (GPU acceleration)
- **Language**: auto (automatic detection, supports 99 languages)

## Running Instructions

### Interactive Menu (Recommended)
```bash
chmod +x menu.sh
./menu.sh
```

### Direct Commands
```bash
sudo -E python3 key_listener.py
```

After launching, you can immediately use the **Double-Tap Control** shortcut.

## Environment Variables for Tuning

### Nemotron Server Configuration (nemotron_stt_server.py)
- `STT_SOCKET` (default: `/tmp/stt_server.sock`) - Unix socket path shared with the client.
- `STT_LANG` (default: `auto`) - Language, or a locale such as `it-IT` to force one.
- `STT_DTYPE` (default: `bfloat16`) - Inference dtype; use `float32` as a fallback.
- `STT_PAD_MS` (default: `300`) - Silence padding to avoid clipping the last word.

### Text Cleaning Configuration
- `STT_CLEAN_TEXT` (default: `1`) - Enable/disable text cleaning.
- `STT_REMOVE_FILLERS` (default: `1`) - Remove filler words.
- `STT_FIX_REPETITIONS` (default: `1`) - Fix stuttering.

### Output Mode
- `STT_MODE` (default: `clipboard`) - Choose between `type` (auto-typing) or `clipboard` (manual pasting).
- `STT_ENABLE_DOUBLE_SUPER` (default: `0`) - Set to `1` to allow the double-Super hotkey.

## Troubleshooting Commands
```bash
# Check system status
./menu.sh status

# View logs
tail -f log/key_listener.log
tail -f log/speech_to_text.log
journalctl --user -u nemotron-stt -f

# Check if the Nemotron STT server is running
ls -la /tmp/stt_server.sock
pgrep -f nemotron_stt_server.py
systemctl --user status nemotron-stt

# Test native keys detection (run as root)
sudo ./venv/bin/python3 test_key_logic.py
```

## Performance
The Nemotron server keeps the model in memory, so transcription is near-instant
after the first request (no per-request model reload).
