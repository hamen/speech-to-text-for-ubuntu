# Speech-to-Text for Ubuntu - LLM Context

## App Name & Purpose
**Speech-to-Text for Ubuntu** - A powerful push-to-talk speech recognition system that provides offline transcription using Faster Whisper models with multiple output modes.

## Platform & Environment
- **OS**: Ubuntu 24.04.2 LTS (Linux)
- **Python**: 3.x with virtual environment
- **Desktop**: Wayland/X11 compatible
- **Architecture**: x86_64 (with CUDA/GPU support)

## How It Works (High-Level)
1. **Push-to-Talk Recording**: User presses and holds a hotkey (F16) to record audio
2. **Audio Processing**: System records audio using `pw-record` (PipeWire) or `arecord` (ALSA)
3. **Offline Transcription**: Audio is processed using Faster Whisper models locally
4. **Output Modes**: User can choose between automatic typing or clipboard + notification
5. **Fallback System**: Multiple input methods for maximum compatibility

## Key Files & Their Purpose

### Core Scripts
- **`key_listener.py`** - Main orchestrator: listens for hotkey, records audio, calls speech processing
- **`speech_to_text.py`** - Audio processor: loads audio, transcribes with Whisper, handles output modes
- **`menu.sh`** - Beautiful interactive interface using [Gum](https://github.com/charmbracelet/gum) for setup and management
- **`run.sh`** - Automated setup script for dependencies and system launch

### Configuration & Logs
- **`log/`** - Dedicated directory for all system logs (gitignored)
- **`.gitignore`** - Prevents logs, temp files, and build artifacts from being committed
- **`requirements.txt`** - Python dependencies for the virtual environment

## Defaults & Paths
- **Hotkey**: F16 (remapped from Shift+Ctrl+F12 via input-remapper)
- **Audio File**: `/tmp/recorded_audio.wav`
- **Log Files**: `log/key_listener.log`, `log/speech_to_text.log`
- **Output File**: `/tmp/speech_to_text_output.txt`
- **Python Venv**: `venv/bin/python3`
- **ydotool Socket**: `/tmp/.ydotool_socket`

## Running Instructions

### Interactive Menu (Recommended)
```bash
chmod +x menu.sh
./menu.sh
```

### Direct Commands
```bash
# Install dependencies
./menu.sh install

# Run with auto-typing
./menu.sh type

# Run with clipboard mode (no typing)
./menu.sh clipboard

# Run in background
./menu.sh background

# Check system status
./menu.sh status
```

### Manual Execution
```bash
# Run as root (required for input device access)
sudo python3 key_listener.py
```

## Environment Variables for Tuning

### Model Configuration
- `STT_MODEL` (default: `tiny.en`) - Whisper model size: `tiny.en`, `base.en`, `small.en`, `medium.en`, `large-v3`
- `STT_DEVICE` (default: `cpu`) - Processing device: `cpu`, `cuda`, `rocm`, `auto`
- `STT_COMPUTE_TYPE` - Defaults to `int8` on CPU, `float16` on GPU
- `STT_BEAM_SIZE` (default: `1`) - Higher values = better accuracy, slower processing
- `STT_LANGUAGE` (default: `en`) - Language hint for transcription
- `STT_VAD` (default: `1`) - Voice Activity Detection (set to `0` to disable)
- `STT_CONDITION` (default: `1`) - Text conditioning (set to `0` for mixed-language)
- `STT_TEMPERATURE` (default: `0.0`) - Higher values = more creative, lower = deterministic

### Output Mode
- `STT_MODE` (default: `clipboard`) - Choose between `type` (auto-typing) or `clipboard` (manual pasting)

## Wayland vs Xorg Typing

### Auto-Typing Mode (`STT_MODE=type`)
1. **pyautogui** (X11 sessions)
2. **wtype** (Wayland virtual keyboard protocol)
3. **ydotool** (Wayland daemon-based input)
4. **Root ydotool fallback** (if user-level methods fail)

### Manual Pasting Mode (`STT_MODE=clipboard`)
- **No automatic typing**
- Text copied to clipboard using `wl-copy` (Wayland) or `xclip`/`xsel` (X11)
- Desktop notification with text preview
- User manually pastes with Ctrl+V

## Dependencies & Installation

### System Packages
- `alsa-utils` - Audio recording
- `python3-evdev` - Input device access
- `wl-clipboard` - Wayland clipboard management
- `libnotify-bin` - Desktop notifications
- `wtype` - Wayland virtual keyboard
- `ydotool` + `ydotoold` - Wayland input simulation

### Python Packages
- `numpy` - Audio processing
- `soundfile` - Audio file handling
- `faster-whisper` - Whisper model inference
- `pyautogui` - X11 input simulation

## Gotchas & Guidance for LLM

### Common Issues
1. **Permission Errors**: Scripts must run as root for input device access
2. **Audio Recording**: Prefers PipeWire (`pw-record`) over ALSA (`arecord`)
3. **Wayland Compatibility**: Virtual keyboard protocol may be disabled in GNOME
4. **Focus Issues**: Auto-typing can type in wrong window if focus changes

### Best Practices
1. **Use Interactive Menu**: `./menu.sh` handles most setup automatically
2. **Choose Output Mode**: Clipboard mode is more reliable for Wayland
3. **Check Logs**: Monitor `log/` directory for troubleshooting
4. **Test Hotkey**: Ensure F16 is properly mapped and not used by other applications

### Recent Improvements
- **Dual Output Modes**: Clean separation between auto-typing and manual pasting
- **Beautiful Interface**: Gum-powered interactive menu for easy management
- **Organized Logging**: Dedicated log directory with proper gitignore
- **Mode Respect**: Key listener now properly respects STT_MODE environment variable

## Future Ideas
- **Model Switching**: Runtime model selection via menu
- **Hotkey Customization**: Configurable key bindings
- **Audio Quality**: Configurable sample rate and format
- **Language Detection**: Automatic language identification
- **Batch Processing**: Process multiple audio files
- **API Integration**: Webhook notifications for processed text
- **Voice Commands**: Execute system commands via voice
- **Custom Models**: Fine-tuned Whisper models for specific domains

## Troubleshooting Commands
```bash
# Check system status
./menu.sh status

# View logs
tail -f log/key_listener.log
tail -f log/speech_to_text.log

# Check if ydotoold is running
ps aux | grep ydotoold

# Test hotkey detection
sudo evtest /dev/input/event*

# Verify audio recording
pw-record --help
arecord --help
```
