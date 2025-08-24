# Speech-to-Text for Ubuntu - LLM Context

## App Name & Purpose
**Speech-to-Text for Ubuntu** - A powerful push-to-talk speech recognition system that provides offline transcription using Faster Whisper models with **GPU acceleration**, **intelligent text cleaning**, and multiple output modes. Optimized for NVIDIA RTX 4070 and other CUDA GPUs.

## Platform & Environment
- **OS**: Ubuntu 24.04.2 LTS (Linux)
- **Python**: 3.x with virtual environment
- **Desktop**: Wayland/X11 compatible
- **Architecture**: x86_64 with **NVIDIA RTX 4070 GPU acceleration**
- **CUDA**: 12.9 with optimized PyTorch installation

## How It Works (High-Level)
1. **Push-to-Talk Recording**: User presses and holds a hotkey (F16) to record audio
2. **Audio Processing**: System records audio using `pw-record` (PipeWire) or `arecord` (ALSA)
3. **Offline Transcription**: Audio is processed using Faster Whisper models locally with GPU acceleration
4. **Intelligent Text Cleaning**: Transcribed text is automatically cleaned to remove speech artifacts while preserving meaningful content
5. **Output Modes**: User can choose between automatic typing or clipboard + notification
6. **Fallback System**: Multiple input methods for maximum compatibility

## Key Files & Their Purpose

### Core Scripts
- **`key_listener.py`** - Main orchestrator: listens for hotkey, records audio, calls speech processing
- **`speech_to_text.py`** - Audio processor: loads audio, transcribes with Whisper, handles output modes, applies intelligent text cleaning
- **`menu.sh`** - Beautiful interactive interface using [Gum](https://github.com/charmbracelet/gum) for setup and management, includes dedicated large-v3 GPU configuration
- **`run.sh`** - Automated setup script for dependencies and system launch with GPU optimization
- **`large-v3-config.sh`** - Optimized configuration for RTX 4070 with best quality transcription
- **`launch-large-v3.sh`** - One-command launcher for large-v3 GPU configuration

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
- **GPU Model**: large-v3 (best quality, ~3GB VRAM usage)
- **GPU Device**: cuda (GPU acceleration)
- **Text Cleaning**: Conservative mode (preserves meaningful content)

## Running Instructions

### Interactive Menu (Recommended)
```bash
chmod +x menu.sh
./menu.sh
```

**New Menu Options:**
- **4️⃣ 🚀 Run Large-v3 GPU (Recommended)** - Best quality with GPU acceleration and text cleaning
- **7️⃣ 🧪 Test Large-v3 Configuration** - Verify GPU setup and model loading

### Direct Commands
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

### Manual Execution
```bash
# Run as root (required for input device access)
sudo python3 key_listener.py

# Large-v3 GPU configuration
sudo ./launch-large-v3.sh

# Or load configuration manually
source ./large-v3-config.sh
python3 speech_to_text.py <audio_file>
```

## Environment Variables for Tuning

### Model Configuration
- `STT_MODEL` (default: `large-v3`) - Whisper model size: `tiny.en`, `base.en`, `small.en`, `medium.en`, `large-v3`
- `STT_DEVICE` (default: `cuda`) - Processing device: `cpu`, `cuda`, `rocm`, `auto`
- `STT_COMPUTE_TYPE` (default: `float16`) - Optimized for RTX 4070: `int8` on CPU, `float16` on GPU
- `STT_BEAM_SIZE` (default: `5`) - Higher values = better accuracy, slower processing (1-5 recommended for GPU)
- `STT_LANGUAGE` (default: `en`) - Language hint for transcription
- `STT_VAD` (default: `1`) - Voice Activity Detection (set to `0` to disable)
- `STT_CONDITION` (default: `1`) - Text conditioning (set to `0` for mixed-language)
- `STT_TEMPERATURE` (default: `0.0`) - Higher values = more creative, lower = deterministic

### Text Cleaning Configuration
- `STT_CLEAN_TEXT` (default: `1`) - Enable/disable text cleaning (set to `0` to disable)
- `STT_REMOVE_FILLERS` (default: `1`) - Remove filler words like "um", "uh", "you know" (set to `0` to disable)
- `STT_FIX_REPETITIONS` (default: `1`) - Fix stuttering and word repetitions (set to `0` to disable)
- `STT_FIX_PUNCTUATION` (default: `1`) - Clean up excessive punctuation (set to `0` to disable)
- `STT_MIN_SENTENCE_WORDS` (default: `2`) - Minimum words required for a sentence to be kept
- `STT_AGGRESSIVE_CLEANING` (default: `0`) - Conservative vs aggressive cleaning mode (0 = conservative, 1 = aggressive)
- `STT_PRESERVE_COMMON_WORDS` (default: `1`) - Preserve meaningful words like "okay", "well", "now"

### Example Usage
```bash
# Disable text cleaning completely
export STT_CLEAN_TEXT=0

# Keep fillers but fix repetitions
export STT_REMOVE_FILLERS=0
export STT_FIX_REPETITIONS=1

# More aggressive cleaning (require longer sentences)
export STT_MIN_SENTENCE_WORDS=3

# Custom model with aggressive cleaning
export STT_MODEL=base.en
export STT_CLEAN_TEXT=1
export STT_REMOVE_FILLERS=1
export STT_FIX_REPETITIONS=1
export STT_FIX_PUNCTUATION=1
```

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
- `nvidia-driver-*` - NVIDIA GPU drivers (for CUDA acceleration)

### Python Packages
- `numpy` - Audio processing
- `soundfile` - Audio file handling
- `faster-whisper` - Whisper model inference
- `pyautogui` - X11 input simulation
- `torch` (CUDA-optimized) - PyTorch for GPU acceleration
- `librosa` - Advanced audio processing (optional)
- `scipy` - Scientific computing (optional)

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
- **`test-large-v3.sh`** - Comprehensive large-v3 testing
- **`download-models.sh`** - Download and test all available models
- **`switch-model.sh`** - Easy model switching for testing

## Text Cleaning Features

The system now includes intelligent text cleaning that transforms raw speech transcription into clean, readable text:

### **🧹 What Gets Cleaned:**
- **Filler words**: "um", "uh", "you know" (conservative mode)
- **Repetitions**: "I I I think" → "I think"
- **Stuttering**: "I-I-I think" → "I think"
- **False starts**: Incomplete thoughts and sentence fragments
- **Excessive punctuation**: Multiple periods, commas, or hyphens
- **Sentence structure**: Proper capitalization and sentence endings

### **⚙️ Cleaning Modes:**
- **Conservative Mode (Default)**: Preserves meaningful words like "okay", "well", "now"
- **Aggressive Mode**: Removes more filler words but may remove some meaningful content

### **🔧 Configuration:**
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

### **📝 Example Results:**
```
Original: "Okay, let's try to do this. Now I'm gonna kind of... Oh no, I'm kind of rambling."
Cleaned:  "Okay, let's try to do this. Now I'm gonna kind of. Oh no, I'm kind of rambling."
```

**Key improvements**: "Okay" preserved, "kind of" preserved, natural speech patterns maintained.

### What Gets Cleaned
- **Filler Words**: "um", "uh", "you know", "like", "basically", "actually"
- **Repetitions**: "I I I think" → "I think", "the the the thing" → "the thing"
- **Stuttering**: "I-I-I think" → "I think"
- **False Starts**: Incomplete thoughts and sentence fragments
- **Excessive Punctuation**: Multiple periods, commas, or hyphens
- **Sentence Structure**: Proper capitalization and sentence endings

### Configuration Options
- **Disable Cleaning**: Set `STT_CLEAN_TEXT=0` to get raw transcription
- **Customize Fillers**: Modify `STT_REMOVE_FILLERS` to control filler word removal
- **Adjust Repetition Fixing**: Use `STT_FIX_REPETITIONS` to control stuttering fixes
- **Punctuation Control**: Set `STT_FIX_PUNCTUATION` to manage punctuation cleaning
- **Sentence Length**: Configure `STT_MIN_SENTENCE_WORDS` for minimum sentence length

### Example Transformations
```
Raw: "um I I I think that um you know the the the thing is basically um actually"
Clean: "I think that the thing is."
```

## Future Ideas
- **Model Switching**: Runtime model selection via menu
- **Hotkey Customization**: Configurable key bindings
- **Audio Quality**: Configurable sample rate and format
- **Language Detection**: Automatic language identification
- **Batch Processing**: Process multiple audio files
- **API Integration**: Webhook notifications for processed text
- **Voice Commands**: Execute system commands via voice
- **Custom Models**: Fine-tuned Whisper models for specific domains
- **Advanced Text Cleaning**: Machine learning-based sentence completion and grammar correction

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

# GPU-specific troubleshooting
./test-gpu.sh                    # Test GPU acceleration
nvidia-smi                       # Check GPU status and memory
source gpu-config.sh             # Load optimal GPU settings
python3 -c "import torch; print(torch.cuda.is_available())"  # Test PyTorch CUDA

# Large-v3 GPU testing
./test-large-v3.sh               # Test large-v3 configuration
./launch-large-v3.sh             # Launch large-v3 GPU system
source large-v3-config.sh        # Load large-v3 configuration

# Text cleaning testing
./test-text-cleaning.sh          # Test conservative vs aggressive cleaning

# Model management
./download-models.sh             # Download and test all models
./switch-model.sh -l             # List available models
./switch-model.sh -m large-v3    # Switch to large-v3 model
```
