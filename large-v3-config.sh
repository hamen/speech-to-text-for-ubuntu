#!/bin/bash

# Large-v3 GPU Configuration for Speech-to-Text
# Optimized for NVIDIA RTX 4070 (12GB VRAM)

set -e

# Load persistent configuration if available
if [[ -f "$HOME/.config/speech-to-text/config.conf" ]]; then
    echo "📁 Loading persistent configuration..."
    source "$HOME/.config/speech-to-text/config.conf"
    echo "✅ Persistent configuration loaded"
else
    echo "📁 No persistent configuration found, using defaults"
fi

# =============================================================================
# GPU CONFIGURATION (with fallback to defaults if not in persistent config)
# =============================================================================

# Model Selection
export STT_MODEL="${STT_MODEL:-large-v3-turbo}"              # Fast, high-quality transcription with lower VRAM use

# Check if cuDNN is available for GPU mode
_check_cudnn() {
    # Method 1: Check ldconfig cache
    if ldconfig -p 2>/dev/null | grep -q "libcudnn"; then
        return 0
    fi
    # Method 2: Check common library paths directly (suppress glob errors)
    for lib_path in /usr/lib/x86_64-linux-gnu /usr/local/lib /usr/lib; do
        if find "$lib_path" -maxdepth 1 -name 'libcudnn*.so*' 2>/dev/null | head -1 | grep -q libcudnn; then
            return 0
        fi
    done
    # Method 3: Check if nvidia-cudnn package is installed
    if dpkg -l nvidia-cudnn 2>/dev/null | grep -q "^ii"; then
        return 0
    fi
    return 1
}

if [[ "${STT_DEVICE:-auto}" == "cuda" ]] || [[ "${STT_DEVICE:-auto}" == "auto" ]]; then
    if ! _check_cudnn; then
        echo "⚠️  cuDNN not found - falling back to CPU mode"
        echo "   To enable GPU: sudo apt install nvidia-cudnn"
        export STT_DEVICE="cpu"
        export STT_COMPUTE_TYPE="int8"
    else
        export STT_DEVICE="${STT_DEVICE:-cuda}"
        export STT_COMPUTE_TYPE="${STT_COMPUTE_TYPE:-int8_float16}"
    fi
else
    export STT_DEVICE="${STT_DEVICE:-cuda}"
    if [[ "$STT_DEVICE" == "cpu" ]]; then
        export STT_COMPUTE_TYPE="${STT_COMPUTE_TYPE:-int8}"
    else
        export STT_COMPUTE_TYPE="${STT_COMPUTE_TYPE:-int8_float16}"
    fi
fi
export STT_BEAM_SIZE="${STT_BEAM_SIZE:-5}"                    # Maximum accuracy
export STT_TEMPERATURE="${STT_TEMPERATURE:-0.0}"              # Deterministic output
export STT_VAD="${STT_VAD:-1}"                               # Voice Activity Detection
export STT_CONDITION="${STT_CONDITION:-1}"                    # Text conditioning
export STT_LANGUAGE="${STT_LANGUAGE:-auto}"                    # Auto-detect language (supports 99 languages)

# Output Mode
export STT_MODE="${STT_MODE:-clipboard}"                      # Manual pasting (reliable)

# Text Cleaning (Post-Processing)
export STT_CLEAN_TEXT="${STT_CLEAN_TEXT:-1}"                  # Enable intelligent text cleaning
export STT_REMOVE_FILLERS="${STT_REMOVE_FILLERS:-1}"          # Remove filler words like "um", "uh"
export STT_FIX_REPETITIONS="${STT_FIX_REPETITIONS:-1}"        # Fix stuttering and duplicates
export STT_FIX_PUNCTUATION="${STT_FIX_PUNCTUATION:-1}"        # Clean up excessive punctuation
export STT_MIN_SENTENCE_WORDS="${STT_MIN_SENTENCE_WORDS:-2}"  # Minimum words for sentence
export STT_AGGRESSIVE_CLEANING="${STT_AGGRESSIVE_CLEANING:-0}"    # 0 = conservative, 1 = aggressive
export STT_PRESERVE_COMMON_WORDS="${STT_PRESERVE_COMMON_WORDS:-1}"  # Preserve meaningful words like "okay", "well"

# Sound Notification (replaces desktop notifications)
export STT_USE_SOUND="${STT_USE_SOUND:-1}"                    # Enable sound notification (default)
export STT_SOUND_FILE="${STT_SOUND_FILE:-/usr/share/sounds/freedesktop/stereo/complete.oga}"  # Completion sound
export STT_USE_NOTIFICATION="${STT_USE_NOTIFICATION:-0}"             # Disable desktop notifications by default

echo "🎯 Large-v3 GPU Configuration for RTX 4070"
echo "=========================================="
echo ""

# Check GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ No NVIDIA GPU detected"
    echo "   This configuration requires GPU acceleration"
    exit 1
fi

echo "🎮 GPU Detected:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | while IFS=, read -r name memory; do
    echo "   $name (${memory}MB VRAM)"
done
echo ""

# =============================================================================
# OPTIMAL LARGE-V3 CONFIGURATION
# =============================================================================

# Model Configuration (loaded from persistent config — do not override here)
export STT_MODEL="${STT_MODEL:-large-v3-turbo}"            # turbo: ~3-4x faster, ~1GB VRAM, qualita' IT/EN ~equivalente a large-v3
export STT_DEVICE="${STT_DEVICE:-cuda}"                    # GPU acceleration
export STT_COMPUTE_TYPE="${STT_COMPUTE_TYPE:-int8_float16}"  # int8 weights + fp16 compute: taglio VRAM, perdita impercettibile

# Quality vs Speed Optimization
# STT_BEAM_SIZE is loaded from persistent config (line 25) - do not override here
export STT_TEMPERATURE="0.0"          # Deterministic output (0.0 = most accurate)
export STT_VAD="1"                    # Voice Activity Detection enabled
export STT_CONDITION="1"              # Text conditioning enabled
# STT_LANGUAGE is loaded from persistent config (line 29) - do not override here
# Options: "auto" (detect), "en" (English), "it" (Italian), "de" (German), etc.

# =============================================================================
# MANUAL PASTING MODE (No Automatic Typing)
# =============================================================================

export STT_MODE="clipboard"           # Manual pasting mode
                                      # Text copied to clipboard + notification
                                      # User manually pastes with Ctrl+V
                                      # More reliable than automatic typing

# =============================================================================
# POST-PROCESSING TEXT CLEANING (Enabled)
# =============================================================================

# Enable all text cleaning features
# Set text cleaning configuration for optimal results
export STT_CLEAN_TEXT="1"             # 1 = enabled, 0 = disabled
export STT_REMOVE_FILLERS="1"         # Remove "um", "uh", "you know" (conservative)
export STT_FIX_REPETITIONS="1"        # Fix stuttering and word repetitions
export STT_FIX_PUNCTUATION="1"        # Clean up excessive punctuation
export STT_MIN_SENTENCE_WORDS="2"     # Minimum words for a sentence to be kept
export STT_AGGRESSIVE_CLEANING="0"    # 0 = conservative, 1 = aggressive
export STT_PRESERVE_COMMON_WORDS="1"  # Preserve meaningful words like "okay", "well"

# Sound Notification (replaces desktop notifications)
export STT_USE_SOUND="1"                    # Enable sound notification (default)
export STT_SOUND_FILE="/usr/share/sounds/freedesktop/stereo/complete.oga"  # Completion sound
export STT_USE_NOTIFICATION="0"             # Disable desktop notifications by default

# =============================================================================
# PERFORMANCE TUNING FOR RTX 4070
# =============================================================================

# These settings are optimized for your RTX 4070:
# - large-v3-turbo: Fast, high-quality transcription, ~1GB VRAM usage
# - int8_float16: Lower VRAM usage with fp16 compute on CUDA
# - beam_size=5: Maximum accuracy without being too slow
# - VAD enabled: Reduces processing of silence
# - Text cleaning: Post-processes for professional-quality output

# =============================================================================
# USAGE INSTRUCTIONS
# =============================================================================

echo "✅ Configuration Loaded Successfully!"
echo ""
echo "🎯 Model: $STT_MODEL (Best Quality)"
echo "🚀 Device: $STT_DEVICE (GPU Acceleration)"
echo "⚡ Compute Type: $STT_COMPUTE_TYPE"
echo "🎯 Beam Size: $STT_BEAM_SIZE (Maximum Accuracy)"
echo "🌍 Language: $STT_LANGUAGE (auto = detect, en = English, it = Italian)"
echo "📝 Output Mode: $STT_MODE (Manual Pasting)"
echo "🧹 Text Cleaning: $STT_CLEAN_TEXT (Enabled)"
echo ""

echo "💡 How to Use:"
echo "   1. Press F16 (or your hotkey) to start recording"
echo "   2. Speak clearly - $STT_MODEL will provide high-quality transcription"
echo "   3. Text is automatically cleaned and copied to clipboard"
echo "   4. Press Ctrl+V to paste the cleaned text"
echo ""

echo "🔧 Environment Variables Set:"
echo "   STT_MODEL=$STT_MODEL"
echo "   STT_DEVICE=$STT_DEVICE"
echo "   STT_COMPUTE_TYPE=$STT_COMPUTE_TYPE"
echo "   STT_BEAM_SIZE=$STT_BEAM_SIZE"
echo "   STT_LANGUAGE=$STT_LANGUAGE"
echo "   STT_MODE=$STT_MODE"
echo "   STT_CLEAN_TEXT=$STT_CLEAN_TEXT"
echo ""

echo "🚀 Ready to Launch!"
echo "   Run: python3 speech_to_text.py <audio_file>"
echo "   Or: sudo ./run.sh (for full system)"
echo ""

# Verify configuration
echo "🧪 Configuration Verification:"
echo "=============================="

# Check if virtual environment is active
if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    echo "✅ Virtual environment active: $VIRTUAL_ENV"
else
    echo "⚠️  Virtual environment not active"
    echo "   Run: source venv/bin/activate"
fi

# Check GPU memory
echo "🎮 GPU Memory Status:"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | while IFS=, read -r used total; do
    echo "   Used: ${used}MB / Total: ${total}MB"
    echo "   Available: $((total - used))MB for $STT_MODEL model"
done

echo ""
echo "🎉 Large-v3 GPU Configuration Ready!"
echo "   Your RTX 4070 is configured for fast, high-quality transcription!"
