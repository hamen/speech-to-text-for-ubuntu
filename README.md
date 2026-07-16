# Speech-to-Text For Ubuntu

A powerful Python project that provides **push-to-talk speech recognition** using native keyboard shortcuts and automatically transcribes it to text using the **NVIDIA Nemotron 3.5 ASR** model with **GPU acceleration** and **intelligent text cleaning**.

The transcription engine is **[nvidia/nemotron-3.5-asr-streaming-0.6b](https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b)** (FastConformer cache-aware RNNT, multilingual with automatic language detection). It runs in bf16 using only ~1.4 GB VRAM and requires `transformers >= 5.13.0` (native `Nemotron3_5Asr` class). The model is served by a persistent Unix-socket server; there is no local fallback.

**🎯 Key Features:**
- **Push-to-talk recording** - Press and hold to record, release to process
- **Native Keyboard Shortcuts** - **Double-Control** by default; optional **Double-Super** toggle in config
- **⚡ Persistent Model Server** - The Nemotron model stays in memory for **instant transcription**
- **300ms silence padding** - Prevents the last word from being clipped when the push-to-talk key is released while still speaking
- **Multilingual with automatic language detection** - Handles mixed Italian/English dictation without dropping English words
- **Multiple output modes** - Choose between automatic typing or clipboard + notification
- **Interactive menu** - Optional setup and configuration helper with [Gum](https://github.com/charmbracelet/gum)
- **Offline transcription** - Works without internet using the local Nemotron model
- **GPU acceleration** - Optimized for NVIDIA RTX 4070 and other CUDA GPUs
- **Intelligent text cleaning** - Removes speech artifacts while preserving meaningful content
- **Wayland & X11 support** - Compatible with modern Linux desktop environments
- **🌐 OpenAI-Compatible HTTP API** - Expose the local STT server via `POST /v1/audio/transcriptions` for use with [summarize](https://github.com/steipete/summarize) and other tools

Designed for use on Linux systems (tested on Ubuntu 24.04.2 LTS) with GPU acceleration.

## Project Overview

- **key_listener.py**: Monitors keyboard devices for dictation shortcuts. Supports listening on **all connected keyboards** simultaneously, making it robust against remapping tools and different hardware.
- **speech_to_text.py**: Loads the recorded audio, processes it (converts stereo to mono if needed), and sends it to the Nemotron STT server over the Unix socket `/tmp/stt_server.sock` for transcription.
- **nemotron_stt_server.py**: **Persistent model server** that keeps the Nemotron 3.5 ASR model loaded in memory. Runs as the systemd user service `nemotron-stt` and serves transcription requests over the Unix socket.
- **stt_api.py**: **OpenAI-compatible HTTP API** that wraps the Unix socket server. Exposes `POST /v1/audio/transcriptions` on port 8787, making the local GPU-accelerated STT server available to any tool that speaks the OpenAI Whisper API (e.g. `summarize`, custom scripts).
- **menu.sh**: Optional interactive menu powered by [Gum](https://github.com/charmbracelet/gum) for launching the key listener and basic management. The Nemotron server itself is normally managed by systemd.
- **nemotron-stt.service.template**: systemd user service template for the Nemotron STT server (fill in the venv and repo paths).

## 🎤 Keyboard Shortcuts

The system now supports multiple ways to trigger dictation. You can use whichever is most comfortable for you:

### 1. Native "Double-Tap" Shortcuts (Recommended)
These work out of the box without remapping:

- **Double-Tap Left Control**: Press `Left Ctrl`, release, then press & **hold** `Left Ctrl`.
  - Speak while holding. Release to transcribe.
- **Double-Tap Super (Windows)**: Optional and **disabled by default**; enable via config and then press `Super`, release, then press & **hold** `Super`.

### 2. Legacy F16 Shortcut
For backward compatibility or if you prefer remapping a specific key (like a mouse button):
- **Key**: F16
- **Setup**: Use your preferred tool (e.g., input-remapper) to map a key to F16.

## Setup

### Option 1: Interactive Menu (Recommended)

The easiest way to get started is using the beautiful interactive menu:

```bash
# Clone the repository
git clone https://github.com/CDNsun/speech-to-text-for-ubuntu
cd speech-to-text-for-ubuntu

# Make menu executable and run it
chmod +x menu.sh
./menu.sh
```

The menu will guide you through:
1. **Installing Dependencies** - Automatically installs all required packages
2. **Choosing Output Mode** - Select between auto-typing or clipboard + notification
3. **🎙️ Run Nemotron STT** - Launch the key listener against the running Nemotron server
4. **Running the System** - Start in foreground or background
5. **System Status** - Check what's running and troubleshoot issues

### Option 2: systemd + direct launch (recommended)

The Nemotron STT server is meant to run as a systemd user service. Fill in the
paths in `nemotron-stt.service.template`, install it, then start it:

```bash
systemctl --user start nemotron-stt
```

With the server running (socket at `/tmp/stt_server.sock`), start the key listener:

```bash
sudo -E python3 key_listener.py
```

You can then immediately use **Double-Tap Left Control** to dictate.

> **No fallback.** Nemotron is the only engine. The server **must be running** before you
> launch the key listener — there is no local Whisper fallback. If it's down, dictation
> fails loudly (an error sound + notification) and nothing is pasted. Start it with
> `systemctl --user start nemotron-stt`.

> **Upgrading from an older (Whisper/Parakeet) install?** The Parakeet and Whisper engines
> and their `stt-switch.sh` / `parakeet-stt.service` were removed. They shared the same
> socket (`/tmp/stt_server.sock`), so disable any leftover server first to avoid the wrong
> engine staying bound: `systemctl --user disable --now parakeet-stt` (and stop any manual
> `stt_server.py`). The OpenAI-compatible HTTP API (`stt_api.py`) is no longer auto-started
> by the menu — start it manually if `hey_nuc.py` / `summarize` need it (see below).

## Requirements

- Python 3.x
- Linux (tested on Ubuntu 24.04.2 LTS)
- Python virtual environment with required packages installed
- `arecord` or `pw-record` (for audio recording)
- `evdev` (for key listening)
- `transformers` (>= 5.13) for the Nemotron 3.5 ASR model

### For GPU Acceleration (Recommended)
- NVIDIA GPU with CUDA support
- NVIDIA Driver (tested with 580.x)
- **cuDNN library** (required for GPU inference):
  ```bash
  sudo apt install nvidia-cudnn
  ```

### Optional Tools
- `wl-clipboard` - Clipboard support on Wayland
- `xclip` / `xsel` - Clipboard support on X11
- `libnotify-bin` - Desktop notifications
- `input-remapper` - For custom key remapping (F16 shortcut)

## Usage

### Manual Execution
```bash
# Run as root (required to listen to input devices)
sudo -E python3 key_listener.py

# Shortcuts:
# 1. Double-tap and hold Left Control (default)
# 2. Double-tap and hold Left Super (enable via config)
# 3. Press and hold F16 (if you have remapped a key to F16)
```

## How it Works

### ⚡ Persistent Model Server

The system uses a **persistent model server** architecture for instant transcription:

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────────┐
│  key_listener   │────▶│ speech_to_text   │────▶│  nemotron_stt_server │
│  (detects keys) │     │ (processes audio)│     │    (model in RAM)    │
└─────────────────┘     └──────────────────┘     └──────────────────────┘
```

The Nemotron model is loaded once and stays in memory, so transcription is
near-instant after the first request. `speech_to_text.py` talks to the server
over the Unix socket `/tmp/stt_server.sock` (there is no local fallback).

The server runs as the systemd user service `nemotron-stt`:

```bash
systemctl --user start nemotron-stt
```

### 🌐 OpenAI-Compatible HTTP API

The system includes an HTTP API (`stt_api.py`) that exposes the local STT server as an OpenAI-compatible endpoint. This lets external tools use your GPU for transcription.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────────┐
│  HTTP client │────▶│   stt_api    │────▶│  nemotron_stt_server │
│  (port 8787) │     │  (FastAPI)   │     │    (model in RAM)    │
└──────────────┘     └──────────────┘     └──────────────────────┘
```

**Endpoint:** `POST http://localhost:8787/v1/audio/transcriptions`

**Usage with [summarize](https://github.com/steipete/summarize):**
```bash
export OPENAI_WHISPER_BASE_URL=http://localhost:8787/v1
summarize "https://youtu.be/VIDEO_ID" --youtube auto
```

**Standalone usage:**
```bash
# Start the API (if not using menu.sh)
python3 stt_api.py

# Transcribe a file
curl -X POST http://localhost:8787/v1/audio/transcriptions \
  -F file=@audio.wav -F model=nemotron-3.5

# Health check
curl http://localhost:8787/health
```

Start it with `python3 stt_api.py` (it proxies to the running Nemotron server). You can also set `OPENAI_WHISPER_BASE_URL` in your shell profile for permanent access.

### Output Modes

The system supports two distinct output modes that you can choose from:

**🎯 Auto-Typing Mode (`STT_MODE=type`):**
- Automatically types transcribed text into the focused window
- Uses multiple fallback methods: `pyautogui` → `wtype` → `ydotool`
- Includes root-level fallback for maximum compatibility

**📋 Manual Pasting Mode (`STT_MODE=clipboard`):**
- Copies transcribed text to clipboard
- **Automatic session detection**: Uses appropriate clipboard tool for your desktop environment
- **X11/Xfce4 Support**: Fixed clipboard functionality on X11 systems with `xclip`/`xsel`
- **Sound notification** when ready to paste (enabled by default)
- Optional desktop notification with text preview (disabled by default)
- **No automatic typing** - you control where and when to paste
- Perfect for avoiding focus issues and unwanted text input

### Text Cleaning Features

The system includes intelligent text cleaning that transforms raw speech transcription into clean, readable text:

**🧹 What Gets Cleaned:**
- **Filler words**: "um", "uh", "you know" (conservative mode)
- **Repetitions**: "I I I think" → "I think"
- **Stuttering**: "I-I-I think" → "I think"
- **False starts**: Incomplete thoughts and sentence fragments
- **Excessive punctuation**: Multiple periods, commas, or hyphens
- **Sentence structure**: Proper capitalization and sentence endings

## Advanced configuration (environment variables)

You can tweak accuracy/latency and platform settings without changing code. Set these env vars when launching `menu.sh` (it will export from your config) or when running `sudo -E python3 key_listener.py`.

### Nemotron Server Configuration
These are read by `nemotron_stt_server.py` (set them in the systemd unit):
- `STT_SOCKET` (default: `/tmp/stt_server.sock`) — Unix socket path shared with the client.
- `STT_LANG` (default: `auto`) — language, or a locale such as `it-IT` to force one.
- `STT_DTYPE` (default: `bfloat16`) — inference dtype; use `float32` as a fallback.
- `STT_PAD_MS` (default: `300`) — silence padding to avoid clipping the last word.

### Text Cleaning Configuration
- `STT_CLEAN_TEXT` (default: `1`) - Enable/disable text cleaning
- `STT_REMOVE_FILLERS` (default: `1`) - Remove filler words like "um", "uh", "you know"
- `STT_FIX_REPETITIONS` (default: `1`) - Fix stuttering and word repetitions
- `STT_AGGRESSIVE_CLEANING` (default: `0`) - Conservative vs aggressive cleaning mode

### Output Mode
- `STT_MODE` (default: `clipboard`) - Choose between `type` (auto-typing) or `clipboard` (manual pasting)

## Desktop Environment Compatibility

### Wayland Notes
- On GNOME Wayland the virtual keyboard protocol may be disabled by default; enable it in settings or rely on clipboard+notification.
- If `ydotool` is installed and `ydotoold` is available, the system will use it for more reliable typing. `menu.sh` will start `ydotoold` when needed.

### X11/Xfce4 Support
- **✅ Clipboard Fixed**: X11/Xfce4 clipboard functionality now works correctly with automatic session detection
- **Tools Used**: `xclip` (primary) and `xsel` (fallback) for X11 clipboard operations

## 🚀 Nemotron STT Server

The transcription engine is **[nvidia/nemotron-3.5-asr-streaming-0.6b](https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b)** (FastConformer cache-aware RNNT, multilingual with automatic language detection). It runs in **bf16 using only ~1.4 GB VRAM** and loads in ~1s once cached.

**Requires `transformers >= 5.13.0`** (native `Nemotron3_5Asr` class). The stable NeMo PyPI release does **not** ship the required model class, so use the Transformers path.

### Setup (separate venv recommended)

```bash
python3.12 -m venv venv-nemotron
./venv-nemotron/bin/pip install -r requirements-nemotron.txt
# First run downloads the model (~2.5 GB safetensors). Point HF_HOME to a disk with space.
```

### Run

```bash
# Persistent socket server (serves /tmp/stt_server.sock)
STT_LANG=auto STT_DTYPE=bfloat16 ./venv-nemotron/bin/python nemotron_stt_server.py

# One-off streaming from the mic (prints partial hypotheses live, Ctrl-C to stop)
./venv-nemotron/bin/python stream_hf.py auto

# Offline transcription of a file
./venv-nemotron/bin/python transcribe_hf.py audio.wav auto
```

Env vars: `STT_SOCKET` (default `/tmp/stt_server.sock`), `STT_LANG` (default `auto` — recommended; use a locale like `it-IT` to force a language), `STT_DTYPE` (default `bfloat16`), `STT_PAD_MS` (default `300`).

### systemd (user)

Install the user unit so the server starts on login and stays running:
- Copy `nemotron-stt.service.template` → `~/.config/systemd/user/nemotron-stt.service`, replacing `__NEMO_HOME__` and `__VENV__`.

Then reload and start it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now nemotron-stt
systemctl --user status nemotron-stt
```

## License

MIT License

Copyright (c) 2025 CDNsun

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
