# Speech-to-Text For Ubuntu

A powerful Python project that provides **push-to-talk speech recognition** using native keyboard shortcuts and automatically transcribes it to text using Faster Whisper models with **GPU acceleration** and **intelligent text cleaning**.

**🎯 Key Features:**
- **Push-to-talk recording** - Press and hold to record, release to process
- **Native Keyboard Shortcuts** - **Double-Control** by default; optional **Double-Super** toggle in config
- **⚡ Persistent Model Server** - Model stays in memory for **instant transcription** (~0.4s instead of ~2.6s)
- **🌍 Multilingual Support** - 99 languages with automatic detection (Italian, English, Spanish, etc.)
- **Multiple output modes** - Choose between automatic typing or clipboard + notification
- **Beautiful interactive menu** - Easy setup and configuration with [Gum](https://github.com/charmbracelet/gum)
- **Offline transcription** - Works without internet using local Whisper models
- **GPU acceleration** - Optimized for NVIDIA RTX 4070 and other CUDA GPUs
- **Intelligent text cleaning** - Removes speech artifacts while preserving meaningful content
- **Wayland & X11 support** - Compatible with modern Linux desktop environments
- **Configurable models** - From fast `tiny.en` to accurate `large-v3`

Designed for use on Linux systems (tested on Ubuntu 24.04.2 LTS) with optional GPU acceleration.

## Project Overview

- **key_listener.py**: Monitors keyboard devices for dictation shortcuts. Now supports listening on **all connected keyboards** simultaneously, making it robust against remapping tools and different hardware.
- **speech_to_text.py**: Loads the recorded audio, processes it (converts stereo to mono if needed), and transcribes the speech to text using the Faster Whisper model. Automatically uses the persistent server when available for instant transcription.
- **stt_server.py**: **Persistent model server** that keeps the Whisper model loaded in memory. Eliminates the ~2 second model loading time for each transcription request.
- **menu.sh**: Interactive menu powered by [Gum](https://github.com/charmbracelet/gum) for setup, mode selection, and system management. Automatically starts the persistent server.
- **large-v3-config.sh**: Optimized configuration for RTX 4070 with best quality transcription and automatic cuDNN detection.

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
3. **🚀 Run Large-v3 GPU (Recommended)** - Best quality with GPU acceleration and text cleaning
4. **Running the System** - Start in foreground or background
5. **System Status** - Check what's running and troubleshoot issues

### Option 2: Direct launch (power users)

If you prefer to skip the menu, export your desired `STT_` settings (see Advanced configuration) and run:

```bash
sudo -E python3 key_listener.py
```

You can then immediately use **Double-Tap Left Control** to dictate.

## Requirements

- Python 3.x
- Linux (tested on Ubuntu 24.04.2 LTS)
- Python virtual environment with required packages installed
- `arecord` or `pw-record` (for audio recording)
- `evdev` (for key listening)
- Faster Whisper (speech-to-text model)

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
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  key_listener   │────▶│ speech_to_text   │────▶│   stt_server    │
│  (detects keys) │     │ (processes audio)│     │ (model in RAM)  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

- **Without server**: Each transcription takes ~2.6s (model loads every time)
- **With server**: Each transcription takes ~0.4s (model stays in memory)

The menu automatically starts the server when you select "🚀 Run Large-v3 GPU (Recommended)".

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

### Model Configuration
- `STT_MODEL` (default: `large-v3`) — examples: `tiny.en`, `base.en`, `small.en`, `medium.en`, `large-v3`.
- `STT_DEVICE` (default: `cuda`) — `cuda`, `rocm`, `auto`, or `cpu`.
- `STT_COMPUTE_TYPE` — defaults to `float16` on GPU, `int8` on CPU. Options: `int8`, `int8_float16`, `float16`, `float32`.
- `STT_BEAM_SIZE` (default: `5`) — increase (e.g., `5`) for better accuracy, slightly slower.
- `STT_LANGUAGE` (default: `auto`) — language code or `auto` for automatic detection. Examples: `en`, `it`, `es`, `de`, `fr`.

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
