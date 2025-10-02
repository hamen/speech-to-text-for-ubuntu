# Speech-to-Text For Ubuntu

A powerful Python project that provides **push-to-talk speech recognition** using a hotkey (such as a remapped mouse side button) and automatically transcribes it to text using Faster Whisper models with **GPU acceleration** and **intelligent text cleaning**.

**🎯 Key Features:**
- **Push-to-talk recording** - Press and hold to record, release to process
- **Multiple output modes** - Choose between automatic typing or clipboard + notification
- **Beautiful interactive menu** - Easy setup and configuration with [Gum](https://github.com/charmbracelet/gum)
- **Offline transcription** - Works without internet using local Whisper models
- **GPU acceleration** - Optimized for NVIDIA RTX 4070 and other CUDA GPUs
- **Intelligent text cleaning** - Removes speech artifacts while preserving meaningful content
- **Wayland & X11 support** - Compatible with modern Linux desktop environments
- **Configurable models** - From fast `tiny.en` to accurate `large-v3`

Designed for use on Linux systems (tested on Ubuntu 24.04.2 LTS) with optional GPU acceleration.

## Project Overview

- **key_listener.py**: Monitors a designated key (such as F16, which can be mapped to a mouse button or to any other key) to control audio recording. Recording begins when the key is pressed and ends upon release, at which point speech-to-text processing is automatically initiated.

- **speech_to_text.py**: Loads the recorded audio, processes it (converts stereo to mono if needed), and transcribes the speech to text using the Faster Whisper model. Supports multiple output modes and includes intelligent text cleaning.

- **menu.sh**: Beautiful interactive menu powered by [Gum](https://github.com/charmbracelet/gum) for easy setup, mode selection, and system management. Now includes dedicated large-v3 GPU configuration.

- **run.sh**: Automated setup script that installs dependencies and launches the system.

- **large-v3-config.sh**: Optimized configuration for RTX 4070 with best quality transcription.

## Requirements

- Python 3.x
- Linux (tested on Ubuntu 24.04.2 LTS)
- Python virtual environment with required packages installed (see below)
- `arecord` (for audio recording)
- `evdev` (for key listening)
- A speech-to-text model Faster Whisper
- **Optional**: NVIDIA GPU with CUDA support for acceleration

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
5. **🧪 Test Large-v3 Configuration** - Verify GPU setup and model loading
6. **System Status** - Check what's running and troubleshoot issues

### Option 2: Large-v3 GPU Configuration (Recommended for RTX 4070)

For maximum quality transcription with GPU acceleration:

```bash
# Test your GPU configuration
./test-large-v3.sh

# Launch with large-v3 GPU optimization
sudo ./launch-large-v3.sh

# Or load configuration manually
source ./large-v3-config.sh
python3 speech_to_text.py <audio_file>
```

### Option 3: Manual Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/CDNsun/speech-to-text-for-ubuntu
   cd speech-to-text-for-ubuntu
   ```
2. **Create and activate a Python virtual environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```
4. **Install required system packages**
   ```bash
   sudo apt install -y alsa-utils python3-evdev
   ```
5. **Install optional but recommended tooling (Wayland/Xorg helpers)**
   ```bash
   # Input inspection
   sudo apt install -y evtest

   # Install clipboard tools based on your desktop environment:
   # For Wayland (GNOME, KDE Plasma, etc.):
   sudo apt install -y wl-clipboard libnotify-bin

   # For X11/Xfce4:
   sudo apt install -y xclip xsel libnotify-bin

   # Wayland typing helpers
   sudo apt install -y wtype ydotool

   # GPU acceleration (if you have NVIDIA GPU)
   sudo apt install -y nvidia-driver-*
   ```

6. **Remap your mouse button to an unused key (e.g., F16) using input-remapper or similar tool.**

## Usage

### 1. Interactive Menu (Recommended)

Launch the beautiful interactive menu:
```bash
./menu.sh
```

**Menu Options:**
- **1️⃣ Install Dependencies** - One-click setup of all required packages
- **2️⃣ Run with Auto-Typing** - Text appears automatically in focused window
- **3️⃣ Run with Manual Pasting** - Text copied to clipboard with notification (no typing)
- **4️⃣ 🚀 Run Large-v3 GPU (Recommended)** - Best quality with GPU acceleration and text cleaning
- **5️⃣ Run in Background** - Start as background service with GPU options
- **6️⃣ Check System Status** - Monitor what's running, GPU status, and troubleshoot
- **7️⃣ 🧪 Test Large-v3 Configuration** - Verify GPU acceleration and model loading
- **8️⃣ Help & Information** - Usage instructions and tips

### 2. Command Line Usage

**Direct commands:**
```bash
# Install dependencies
./menu.sh install

# Run with auto-typing
./menu.sh type

# Run with clipboard mode (no typing)
./menu.sh clipboard

# Run large-v3 GPU configuration
./menu.sh large-v3

# Run in background
./menu.sh background

# Check system status
./menu.sh status

# Test large-v3 configuration
./menu.sh test-large-v3
```

**Manual execution:**
```bash
# Run as root (required for input device access)
sudo python3 key_listener.py

# Press and hold your chosen key (e.g., F16/mouse button) to start recording
# Release the key to stop recording and trigger speech-to-text
```

### 3. GPU-Optimized Configuration

For users with NVIDIA GPUs (especially RTX 4070), the system provides optimized configurations:

```bash
# Load optimal GPU settings
source ./gpu-config.sh

# Test GPU acceleration
./test-gpu.sh

# Download and test all available models
./download-models.sh

# Switch between models easily
./switch-model.sh -m large-v3    # Best quality
./switch-model.sh -m medium.en   # Balanced
./switch-model.sh -m tiny.en     # Fastest
```

## How it Works

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

The system now includes intelligent text cleaning that transforms raw speech transcription into clean, readable text:

**🧹 What Gets Cleaned:**
- **Filler words**: "um", "uh", "you know" (conservative mode)
- **Repetitions**: "I I I think" → "I think"
- **Stuttering**: "I-I-I think" → "I think"
- **False starts**: Incomplete thoughts and sentence fragments
- **Excessive punctuation**: Multiple periods, commas, or hyphens
- **Sentence structure**: Proper capitalization and sentence endings

**⚙️ Cleaning Modes:**
- **Conservative Mode (Default)**: Preserves meaningful words like "okay", "well", "now"
- **Aggressive Mode**: Removes more filler words but may remove some meaningful content

**🔧 Configuration:**
```bash
# Conservative mode (default)
export STT_AGGRESSIVE_CLEANING="0"
export STT_PRESERVE_COMMON_WORDS="1"

# Aggressive mode
export STT_AGGRESSIVE_CLEANING="1"

# Disable specific features
export STT_REMOVE_FILLERS="0"        # Keep all words
export STT_FIX_REPETITIONS="0"       # Keep repetitions
export STT_FIX_PUNCTUATION="0"       # Keep all punctuation
```

### System Components

- **key_listener.py**
  - Listens for a specific key event using `evdev`.
  - Starts `arecord` to record audio when the key is pressed.
  - Stops recording when the key is released.
  - Calls `speech_to_text.py` to transcribe the recorded audio.
  - Respects `STT_MODE` environment variable for output behavior.

- **speech_to_text.py**
  - Loads the recorded audio file.
  - Converts stereo audio to mono if necessary.
  - Transcribes the audio to text using a Faster Whisper model (configurable).
  - Applies intelligent text cleaning to remove speech artifacts.
  - Outputs text according to selected mode (typing vs clipboard).

- **menu.sh**
  - Beautiful interactive interface powered by [Gum](https://github.com/charmbracelet/gum)
  - Handles dependency installation, mode selection, and system management
  - Provides system status monitoring and troubleshooting tools
  - Includes dedicated large-v3 GPU configuration option

## Advanced configuration (environment variables)

You can tweak accuracy/latency and platform settings without changing code. Set these env vars when launching `run.sh` or `key_listener.py`.

### Model Configuration
- `STT_MODEL` (default: `large-v3`) — examples: `tiny.en`, `base.en`, `small.en`, `medium.en`, `large-v3`.
- `STT_DEVICE` (default: `cuda`) — `cuda`, `rocm`, `auto`, or `cpu`.
- `STT_COMPUTE_TYPE` — defaults to `float16` on GPU, `int8` on CPU. Options: `int8`, `int8_float16`, `float16`, `float32`.
- `STT_BEAM_SIZE` (default: `5`) — increase (e.g., `5`) for better accuracy, slightly slower.
- `STT_LANGUAGE` (default: `en`) — language hint for transcription.
- `STT_VAD` (default: `1`) — set to `0` to disable VAD if it clips words.
- `STT_CONDITION` (default: `1`) — set to `0` to disable conditioning on previous text (helps mixed-language, short phrases).
- `STT_TEMPERATURE` (default: `0.0`) — increase slightly (e.g., `0.2`) if outputs are stuck, lower for determinism.

### Text Cleaning Configuration
- `STT_CLEAN_TEXT` (default: `1`) - Enable/disable text cleaning
- `STT_REMOVE_FILLERS` (default: `1`) - Remove filler words like "um", "uh", "you know"
- `STT_FIX_REPETITIONS` (default: `1`) - Fix stuttering and word repetitions
- `STT_FIX_PUNCTUATION` (default: `1`) - Clean up excessive punctuation
- `STT_MIN_SENTENCE_WORDS` (default: `2`) - Minimum words required for a sentence
- `STT_AGGRESSIVE_CLEANING` (default: `0`) - Conservative vs aggressive cleaning mode
- `STT_PRESERVE_COMMON_WORDS` (default: `1`) - Preserve meaningful words like "okay", "well"

### Output Mode
- `STT_MODE` (default: `clipboard`) - Choose between `type` (auto-typing) or `clipboard` (manual pasting)

### Sound Notification Configuration
- `STT_USE_SOUND` (default: `1`) - Enable sound notification when transcription is complete
- `STT_SOUND_FILE` (default: `/usr/share/sounds/freedesktop/stereo/complete.oga`) - Path to completion sound file
- `STT_USE_NOTIFICATION` (default: `0`) - Enable desktop notifications (disabled by default)

Examples:

```bash
# Best accuracy on GPU (RTX 4070 optimized)
STT_MODEL=large-v3 STT_DEVICE=cuda STT_COMPUTE_TYPE=float16 STT_BEAM_SIZE=5 bash run.sh

# Conservative text cleaning (default)
STT_AGGRESSIVE_CLEANING=0 STT_PRESERVE_COMMON_WORDS=1 bash run.sh

# Aggressive text cleaning
STT_AGGRESSIVE_CLEANING=1 bash run.sh

# Sound notification only (no desktop notifications)
STT_USE_SOUND=1 STT_USE_NOTIFICATION=0 bash run.sh

# Custom completion sound
STT_SOUND_FILE="/usr/share/sounds/freedesktop/stereo/bell.oga" bash run.sh

# Mixed-language short phrases
STT_MODEL=large-v3 STT_DEVICE=cuda STT_COMPUTE_TYPE=float16 STT_LANGUAGE=auto STT_CONDITION=0 STT_BEAM_SIZE=5 bash run.sh
```

## GPU Optimization for RTX 4070

The system is optimized for your **NVIDIA GeForce RTX 4070** with **12GB VRAM** and **CUDA 12.9**:

### **Optimal Configuration**
- **Model**: `large-v3` (best accuracy, ~3GB VRAM usage)
- **Device**: `cuda` (GPU acceleration)
- **Compute Type**: `float16` (optimal precision/speed balance)
- **Beam Size**: `5` (better accuracy without being too slow)

### **Performance Benefits**
- **Speed**: 5-10x faster than CPU processing
- **Accuracy**: `large-v3` model provides significantly better transcription quality
- **Memory**: Efficient VRAM usage with float16 precision
- **Real-time**: Near-instant transcription with GPU acceleration

### **GPU Configuration Files**
- **`gpu-config.sh`** - Load optimal GPU settings
- **`test-gpu.sh`** - Test GPU acceleration and model loading
- **`run.sh`** - Automated setup with GPU optimization
- **`large-v3-config.sh`** - Dedicated large-v3 configuration
- **`launch-large-v3.sh`** - One-command large-v3 launcher

## Logging and Organization

The system now organizes all logs in a dedicated `log/` directory within the project folder:

```
speech-to-text-for-ubuntu/
├── log/                     # 📁 Log directory (gitignored)
│   ├── key_listener.log     # 📝 Key listener activity logs
│   └── speech_to_text.log   # 📝 Speech processing logs
├── large-v3-config.sh       # 🎯 Large-v3 GPU configuration
├── launch-large-v3.sh       # 🚀 Large-v3 launcher
├── test-large-v3.sh         # 🧪 Large-v3 testing
├── gpu-config.sh            # ⚡ GPU optimization
├── test-gpu.sh              # 🔥 GPU testing
├── download-models.sh       # 📥 Model downloader
├── switch-model.sh          # 🔄 Model switcher
├── test-text-cleaning.sh    # 🧹 Text cleaning testing
└── test-sound.sh            # 🔊 Sound notification testing
```

**Benefits:**
- **🧹 Clean repository** - No log files in git history
- **📊 Organized logging** - All logs in one place
- **🎯 Easy troubleshooting** - Clear log locations
- **📝 Comprehensive logging** - Detailed activity tracking
- **🚀 GPU optimization** - Dedicated GPU configuration files
- **🧹 Text cleaning** - Intelligent speech artifact removal
- **🔊 Sound notifications** - Audio feedback instead of desktop notifications

## Desktop Environment Compatibility

### Wayland Notes
- On GNOME Wayland the virtual keyboard protocol may be disabled by default; enable it in settings or rely on clipboard+notification.
- If `ydotool` is installed and `ydotoold` is available, the system will use it for more reliable typing. `run.sh` tries to start `ydotoold` on `/tmp/.ydotoool_socket` with relaxed permissions.

### X11/Xfce4 Support
- **✅ Clipboard Fixed**: X11/Xfce4 clipboard functionality now works correctly with automatic session detection
- **Tools Used**: `xclip` (primary) and `xsel` (fallback) for X11 clipboard operations
- **Installation**: `sudo apt install xclip xsel` for X11 clipboard support
- **Detection**: System automatically detects X11 sessions and prioritizes X11 clipboard tools

### Troubleshooting Desktop Environment Issues

**X11 Clipboard Not Working:**
```bash
# Test clipboard functionality
./test-clipboard.sh

# Install X11 clipboard tools
sudo apt install xclip xsel

# Verify session type
echo $XDG_SESSION_TYPE
echo $DISPLAY
```

**Wayland Clipboard Not Working:**
```bash
# Install Wayland clipboard tools
sudo apt install wl-clipboard

# Test Wayland clipboard
echo "test" | wl-copy && wl-paste
```

## Real-World Usage

**🚀 Daily Driver Success Story**: This system is actively used daily with an **NVIDIA GeForce RTX 4070** and the **large-v3 model** for:
- **💻 Cursor AI Assistant** - Seamless voice-to-code transcription
- **💬 Chat Applications** - Natural conversation flow without speech artifacts
- **📧 Email Writing** - Professional communication with clean, polished text
- **📝 General Writing** - Any application requiring voice input

The **large-v3 model on GPU** provides near-instant, high-quality transcription that makes voice input feel as natural as typing. The intelligent text cleaning ensures your thoughts flow smoothly without the typical speech artifacts that make raw transcription hard to read.

**✅ X11/Xfce4 Support Confirmed**: Clipboard functionality now works perfectly on X11 desktop environments (like Xfce4) with automatic session detection and appropriate clipboard tool selection.

## Notes
- You may need to adjust device paths and user names in the scripts to match your system.
- The script assumes you have a Python virtual environment (e.g., `/home/david/venv/bin/python3`) with the necessary packages installed.
- For GPU acceleration, ensure you have CUDA-compatible PyTorch installed.
- The system automatically downloads Whisper models on first use.

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