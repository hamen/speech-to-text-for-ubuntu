#!/bin/bash

# Large-v3 CPU Configuration for Speech-to-Text
# Optimized for CPU execution to save GPU VRAM

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
# CPU CONFIGURATION
# =============================================================================

# Model Selection
export STT_MODEL="large-v3"           # Best quality transcription
export STT_DEVICE="cpu"               # Force CPU execution
export STT_COMPUTE_TYPE="int8"        # Optimized for CPU (faster than float32)

# Quality vs Speed Optimization
export STT_BEAM_SIZE="${STT_BEAM_SIZE:-5}"
export STT_TEMPERATURE="0.0"          # Deterministic output
export STT_VAD="1"                    # Voice Activity Detection
export STT_CONDITION="1"              # Text conditioning

# Language (Can be 'auto', 'en', 'it', etc.)
# If the user requested It/En, we ensure it's set or defaults to auto
export STT_LANGUAGE="${STT_LANGUAGE:-auto}"

# Output Mode
export STT_MODE="${STT_MODE:-clipboard}"

# Text Cleaning (Post-Processing)
export STT_CLEAN_TEXT="1"
export STT_REMOVE_FILLERS="1"
export STT_FIX_REPETITIONS="1"
export STT_FIX_PUNCTUATION="1"
export STT_MIN_SENTENCE_WORDS="2"
export STT_AGGRESSIVE_CLEANING="0"
export STT_PRESERVE_COMMON_WORDS="1"

# Sound Notification
export STT_USE_SOUND="1"
export STT_SOUND_FILE="/usr/share/sounds/freedesktop/stereo/complete.oga"
export STT_USE_NOTIFICATION="0"

echo "🎯 Large-v3 CPU Configuration"
echo "==========================="
echo ""
echo "✅ Configuration Loaded Successfully!"
echo ""
echo "🎯 Model: $STT_MODEL"
echo "💻 Device: $STT_DEVICE"
echo "⚡ Compute Type: $STT_COMPUTE_TYPE"
echo "🌍 Language: $STT_LANGUAGE"
echo ""
