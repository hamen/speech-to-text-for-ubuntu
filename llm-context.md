# Speech-to-Text for Ubuntu - LLM Context

## App Name & Purpose
**Speech-to-Text for Ubuntu** - A powerful push-to-talk speech recognition system that provides offline transcription using Faster Whisper models with **GPU acceleration**, **intelligent text cleaning**, **persistent model server**, and multiple output modes. Optimized for NVIDIA RTX 4070 and other CUDA GPUs.

## Platform & Environment
- **OS**: Ubuntu 24.04.2 LTS (Linux)
- **Python**: 3.x with virtual environment
- **Desktop**: Wayland/X11 compatible
- **Architecture**: x86_64 with **NVIDIA RTX 4070 GPU acceleration**
- **CUDA**: 12.x with cuDNN for GPU inference
- **Languages**: 99 languages supported with automatic detection

## How It Works (High-Level)
1. **Push-to-Talk Recording**: User triggers recording via one of multiple methods:
   - **Native Double-Tap**: Double-tap and hold **Left Control** or **Left Super**.
   - **Legacy Hotkey**: Press and hold **F16** (often remapped from a mouse button).
2. **Input Detection**: The system listens on **all connected keyboards** simultaneously, ensuring robust detection regardless of remapping tools.
3. **Audio Processing**: System records audio using `pw-record` (PipeWire) or `arecord` (ALSA).
4. **⚡ Instant Transcription**: Audio is sent to the **persistent STT server** which keeps the model in memory (~0.4s instead of ~2.6s).
5. **Intelligent Text Cleaning**: Transcribed text is automatically cleaned to remove speech artifacts while preserving meaningful content.
6. **Output Modes**: User can choose between automatic typing or clipboard + notification.

## Architecture
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  key_listener   │────▶│ speech_to_text   │────▶│   stt_server    │
│  (detects keys) │     │ (processes audio)│     │ (model in RAM)  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                              │   Unix Socket: /tmp/stt_server.sock
```
- **stt_server.py** loads the model once and keeps it in memory
- **speech_to_text.py** automatically connects to the server (falls back to local loading if unavailable)
- **menu.sh** starts the server automatically when launching Large-v3 mode

## Key Files & Their Purpose

### Core Scripts
- **`key_listener.py`** - Main orchestrator: listens for native hotkeys (Ctrl/Super) and legacy F16 across all devices, records audio, calls speech processing.
- **`speech_to_text.py`** - Audio processor: loads audio, connects to STT server for transcription, handles output modes, applies intelligent text cleaning.
- **`stt_server.py`** - **Persistent model server**: keeps Whisper model in memory, handles transcription requests via Unix socket for instant response.
- **`menu.sh`** - Beautiful interactive interface using [Gum](https://github.com/charmbracelet/gum) for setup and management. Automatically starts the persistent server.
- **`run.sh`** - Automated setup script for dependencies and system launch.
- **`large-v3-config.sh`** - Optimized configuration for RTX 4070 with best quality transcription and automatic cuDNN detection.
- **`launch-large-v3.sh`** - One-command launcher for large-v3 GPU configuration.
- **`setup-keyboard-shortcut.sh`** - Automated script to restore legacy Ctrl+Alt+F12 → F16 keyboard mapping (optional now).

### Configuration & Logs
- **`log/`** - Dedicated directory for all system logs (gitignored).
- **`.gitignore`** - Prevents logs, temp files, and build artifacts from being committed.
- **`requirements.txt`** - Python dependencies for the virtual environment.

## Defaults & Paths
- **Native Shortcuts**: Double-Tap Left Control (Hold), Double-Tap Left Super (Hold)
- **Legacy Hotkey**: F16 (remapped from Ctrl+Alt+F12 or Ctrl+Shift+F12 via input-remapper)
- **Input Remapper Config**: `~/.config/input-remapper/presets/ctrl-alt-f12-to-f16.json`
- **STT Server Socket**: `/tmp/stt_server.sock`
- **Audio File**: `/tmp/recorded_audio.wav`
- **Log Files**: `log/key_listener.log`, `log/speech_to_text.log`, `log/stt_server.log`
- **Output File**: `/tmp/speech_to_text_output.txt`
- **Python Venv**: `venv/bin/python3`
- **GPU Model**: large-v3 (best quality, ~3GB VRAM usage)
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
# Launch with large-v3 GPU optimization
sudo ./launch-large-v3.sh
```

After launching, you can immediately use the **Double-Tap Control** shortcut.

## Environment Variables for Tuning

### Model Configuration
- `STT_MODEL` (default: `large-v3`) - Whisper model size.
- `STT_DEVICE` (default: `cuda`) - Processing device.
- `STT_COMPUTE_TYPE` (default: `float16`) - Optimized for RTX 4070.
- `STT_BEAM_SIZE` (default: `5`) - Higher values = better accuracy.
- `STT_LANGUAGE` (default: `auto`) - Language code or `auto` for detection. Examples: `en`, `it`, `es`, `de`, `fr`.

### Text Cleaning Configuration
- `STT_CLEAN_TEXT` (default: `1`) - Enable/disable text cleaning.
- `STT_REMOVE_FILLERS` (default: `1`) - Remove filler words.
- `STT_FIX_REPETITIONS` (default: `1`) - Fix stuttering.

### Output Mode
- `STT_MODE` (default: `clipboard`) - Choose between `type` (auto-typing) or `clipboard` (manual pasting).

## Troubleshooting Commands
```bash
# Check system status
./menu.sh status

# View logs
tail -f log/key_listener.log
tail -f log/speech_to_text.log
tail -f log/stt_server.log

# Check if STT server is running
ls -la /tmp/stt_server.sock
pgrep -f stt_server.py

# Test native keys detection (run as root)
sudo ./venv/bin/python3 test_key_logic.py
```

## Performance
| Mode | Transcription Time | Notes |
|------|-------------------|-------|
| With persistent server | ~0.4s | Model stays in memory |
| Without server | ~2.6s | Model loads each time |
