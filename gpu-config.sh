#!/bin/bash

# GPU-Optimized Configuration for Speech-to-Text
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
# MODEL SELECTION (with fallback to defaults if not in persistent config)
# =============================================================================

# Available models (choose one):
export STT_MODEL="${STT_MODEL:-large-v3}"                    # Best quality (3GB VRAM)
# export STT_MODEL="medium.en"                               # Balanced (1.5GB VRAM)
# export STT_MODEL="small.en"                                # Fast (500MB VRAM)
# export STT_MODEL="base.en"                                 # Faster (150MB VRAM)
# export STT_MODEL="tiny.en"                                 # Fastest (40MB VRAM)

# =============================================================================
# GPU CONFIGURATION (with fallback to defaults if not in persistent config)
# =============================================================================

export STT_DEVICE="${STT_DEVICE:-cuda}"                      # cuda, cpu, auto
export STT_COMPUTE_TYPE="${STT_COMPUTE_TYPE:-float16}"        # float16 (GPU), int8 (CPU)
export STT_BEAM_SIZE="${STT_BEAM_SIZE:-5}"                    # Higher = better accuracy, slower
export STT_TEMPERATURE="${STT_TEMPERATURE:-0.0}"              # 0.0 = deterministic, higher = creative
export STT_VAD="${STT_VAD:-1}"                               # Voice Activity Detection
export STT_CONDITION="${STT_CONDITION:-1}"                    # Text conditioning
export STT_LANGUAGE="${STT_LANGUAGE:-en}"                     # Language hint

# =============================================================================
# QUALITY VS SPEED TRADEOFFS (with fallback to defaults if not in persistent config)
# =============================================================================

# High Quality (slower):
# export STT_MODEL="large-v3"
# export STT_BEAM_SIZE="5"
# export STT_COMPUTE_TYPE="float16"

# Balanced (medium):
# export STT_MODEL="medium.en"
# export STT_BEAM_SIZE="3"
# export STT_COMPUTE_TYPE="float16"

# Fast (lower quality):
# export STT_MODEL="small.en"
# export STT_BEAM_SIZE="1"
# export STT_COMPUTE_TYPE="int8"

# =============================================================================
# TEXT CLEANING (with fallback to defaults if not in persistent config)
# =============================================================================

export STT_CLEAN_TEXT="${STT_CLEAN_TEXT:-1}"                  # Enable text cleaning
export STT_REMOVE_FILLERS="${STT_REMOVE_FILLERS:-1}"          # Remove filler words
export STT_FIX_REPETITIONS="${STT_FIX_REPETITIONS:-1}"        # Fix stuttering
export STT_FIX_PUNCTUATION="${STT_FIX_PUNCTUATION:-1}"        # Clean punctuation
export STT_MIN_SENTENCE_WORDS="${STT_MIN_SENTENCE_WORDS:-2}"  # Min sentence length
export STT_AGGRESSIVE_CLEANING="${STT_AGGRESSIVE_CLEANING:-0}" # 0 = conservative, 1 = aggressive
export STT_PRESERVE_COMMON_WORDS="${STT_PRESERVE_COMMON_WORDS:-1}" # Preserve meaningful words

# =============================================================================
# OUTPUT MODE (with fallback to defaults if not in persistent config)
# =============================================================================

export STT_MODE="${STT_MODE:-clipboard}"                      # type = automatic typing (may be blocked on Wayland)

# Sound Notification (replaces desktop notifications)
export STT_USE_SOUND="${STT_USE_SOUND:-1}"                    # Enable sound notification (default)
export STT_SOUND_FILE="${STT_SOUND_FILE:-/usr/share/sounds/freedesktop/stereo/complete.oga}"  # Completion sound
export STT_USE_NOTIFICATION="${STT_USE_NOTIFICATION:-0}"             # Disable desktop notifications by default

# =============================================================================
# PERFORMANCE TUNING FOR RTX 4070
# =============================================================================

# For RTX 4070 (12GB VRAM), these settings provide optimal balance:
# - large-v3 model: Best accuracy, reasonable speed, ~3GB VRAM
# - float16: Good precision, efficient memory usage
# - beam_size=5: Better accuracy without being too slow
# - VAD enabled: Reduces processing of silence

# =============================================================================
# ADVANCED MODEL COMPARISON
# =============================================================================

# Model Performance on RTX 4070:
# ┌───────────┬──────────┬──────────┬──────────────┬─────────────────┐
# │ Model     │ VRAM     │ Speed    │ Quality      │ Best For        │
# ├───────────┼──────────┼──────────┼──────────────┼─────────────────┤
# │ tiny.en   │ 0.1GB   │ ⚡⚡⚡⚡⚡ │ 🟡 Basic     │ Testing, speed  │
# │ base.en   │ 0.25GB  │ ⚡⚡⚡⚡   │ 🟡 Basic     │ Speed priority  │
# │ small.en  │ 0.5GB   │ ⚡⚡⚡    │ 🟢 Good      │ Balanced        │
# │ medium.en │ 1.5GB   │ ⚡⚡      │ 🟢 Very Good │ Real-time       │
# │ large-v3  │ 3GB     │ ⚡        │ 🔴 Excellent │ Best quality    │
# │ large-v2  │ 3GB     │ ⚡        │ 🔴 Excellent │ Alternative     │
# │ large     │ 3GB     │ ⚡        │ 🔴 Excellent │ Original        │
# └───────────┴──────────┴──────────┴──────────────┴─────────────────┘

# =============================================================================
# USAGE EXAMPLES
# =============================================================================

# Quick start with best quality:
# source gpu-config.sh && python3 speech_to_text.py audio.wav

# Test different models:
# export STT_MODEL="medium.en" && python3 speech_to_text.py audio.wav
# export STT_MODEL="small.en" && python3 speech_to_text.py audio.wav

# Disable text cleaning:
# export STT_CLEAN_TEXT="0" && python3 speech_to_text.py audio.wav

# CPU fallback (if GPU issues):
# export STT_DEVICE="cpu" && export STT_COMPUTE_TYPE="int8" && python3 speech_to_text.py audio.wav

# =============================================================================
# DOWNLOADING NEW MODELS
# =============================================================================

# To download and test all available models:
# ./download-models.sh

# This will download and test:
# - tiny.en, base.en, small.en, medium.en, large-v3, large-v2, large
# - Show VRAM usage and performance metrics
# - Verify GPU compatibility

echo "🚀 GPU Configuration Loaded:"
echo "   Model: $STT_MODEL"
echo "   Device: $STT_DEVICE"
echo "   Compute Type: $STT_COMPUTE_TYPE"
echo "   Beam Size: $STT_BEAM_SIZE"
echo "   Text Cleaning: $STT_CLEAN_TEXT"
echo "   Output Mode: $STT_MODE"
echo ""
echo "💡 Usage: source gpu-config.sh && python3 speech_to_text.py <audio_file>"
echo "📥 Download more models: ./download-models.sh"
