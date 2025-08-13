# Speech-to-Text For Ubuntu

A simple Python project to record audio using a hotkey (such as a remapped mouse side button) and automatically and offline transcribe it to text using a speech-to-text Faster Whisper model. Designed for use on Linux systems (tested on Ubuntu 24.04.2 LTS).

## Project Overview

- **key_listener.py**: Monitors a designated key (such as F16, which can be mapped to a mouse button or to any other key) to control audio recording. Recording begins when the key is pressed and ends upon release, at which point speech-to-text processing is automatically initiated.

- **speech_to_text.py**: Loads the recorded audio, processes it (converts stereo to mono if needed), and transcribes the speech to text using the Faster Whisper model.

## Requirements

- Python 3.x
- Linux (tested on Ubuntu 24.04.2 LTS)
- Python virtual environment with required packages installed (see below)
- `arecord` (for audio recording)
- `evdev` (for key listening)
- A speech-to-text model Faster Whisper

## Setup

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

   # Wayland clipboard + notifications
   sudo apt install -y wl-clipboard libnotify-bin

   # Wayland typing helpers
   sudo apt install -y wtype ydotool
   ```

6. **Remap your mouse button to an unused key (e.g., F16) using input-remapper or similar tool.**

## Usage

### 1. Start the Key Listener

Run as root (required for input device access and sudo):
```bash
sudo python3 key_listener.py
```

- Press and hold your chosen key (e.g., F16/mouse button) to start recording.
- Release the key to stop recording and trigger speech-to-text.

For automatic start on boot you use crontab (for root) similar to this:
```
* * * * * ps -ef | grep "/home/david/Cursor/speech-to-text/key_listener.py" | grep -v grep > /dev/null || /usr/bin/python3 /home/david/Cursor/speech-to-text/key_listener.py >> /tmp/key_listener.log 2>&1 &
```
### 2. Quick Runner

Use the included helper to start everything (installs optional deps, starts ydotoold on Wayland, launches the listener):

```bash
bash run.sh           # foreground
bash run.sh --daemon  # background
```

If you need the `ydotoold` daemon (Wayland typing), you can build/install from source if your distro package lacks `ydotoold`:

```bash
sudo apt install -y build-essential cmake scdoc libevdev-dev libudev-dev libinput-dev git
git clone https://github.com/ReimuNotMoe/ydotool.git /tmp/ydotool && cd /tmp/ydotool && mkdir -p build && cd build \
  && cmake .. && make -j$(nproc) && sudo make install
```

The runner will start `ydotoold` on `/tmp/.ydotool_socket` with relaxed permissions.

### 3. Speech-to-Text Script

This script is called automatically by `key_listener.py`, but you can also run it manually:
```bash
python3 speech_to_text.py /path/to/audio.wav
```

## How it Works

- **key_listener.py**
  - Listens for a specific key event using `evdev`.
  - Starts `arecord` to record audio when the key is pressed.
  - Stops recording when the key is released.
  - Calls `speech_to_text.py` to transcribe the recorded audio.


- **speech_to_text.py**
  - Loads the recorded audio file.
  - Converts stereo audio to mono if necessary.
  - Transcribes the audio to text using a Faster Whisper model (configurable).
  - Types into the active window using `pyautogui` (Xorg). On Wayland it tries `wtype`, then `ydotool` if available. If typing is blocked, it copies text to clipboard and shows a desktop notification.

## Advanced configuration (environment variables)

You can tweak accuracy/latency and platform settings without changing code. Set these env vars when launching `run.sh` or `key_listener.py`.

- `STT_MODEL` (default: `tiny.en`) — examples: `base.en`, `small.en`, `medium.en`, `large-v3`.
- `STT_DEVICE` (default: `cpu`) — `cuda`, `rocm`, `auto`, or `cpu`.
- `STT_COMPUTE_TYPE` — defaults to `int8` on CPU, `float16` on GPU. Options: `int8`, `int8_float16`, `float16`, `float32`.
- `STT_BEAM_SIZE` (default: `1`) — increase (e.g., `5`) for better accuracy, slightly slower.
- `STT_LANGUAGE` (default: `en`) — language hint for transcription.
- `STT_VAD` (default: `1`) — set to `0` to disable VAD if it clips words.
- `STT_CONDITION` (default: `1`) — set to `0` to disable conditioning on previous text (helps mixed-language, short phrases).
- `STT_TEMPERATURE` (default: `0.0`) — increase slightly (e.g., `0.2`) if outputs are stuck, lower for determinism.

Examples:

```bash
# Better accuracy on CPU
STT_MODEL=base.en STT_BEAM_SIZE=5 bash run.sh

# High accuracy on NVIDIA GPU
STT_MODEL=small.en STT_DEVICE=cuda STT_COMPUTE_TYPE=float16 STT_BEAM_SIZE=5 bash run.sh

# Maximum accuracy (most resource intensive)
STT_MODEL=large-v3 STT_DEVICE=cuda STT_COMPUTE_TYPE=float16 STT_BEAM_SIZE=5 bash run.sh

# Mixed-language short phrases (auto-detect, avoid over-conditioning)
STT_MODEL=large-v3 STT_DEVICE=cuda STT_COMPUTE_TYPE=float16 STT_LANGUAGE=auto STT_CONDITION=0 STT_BEAM_SIZE=5 bash run.sh
```

## Wayland notes

- On GNOME Wayland the virtual keyboard protocol may be disabled by default; enable it in settings or rely on clipboard+notification.
- If `ydotool` is installed and `ydotoold` is available, the system will use it for more reliable typing. `run.sh` tries to start `ydotoold` on `/tmp/.ydotool_socket` with relaxed permissions.

## Notes
- You may need to adjust device paths and user names in the scripts to match your system.
- The script assumes you have a Python virtual environment (e.g., `/home/david/venv/bin/python3`) with the necessary packages installed.


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