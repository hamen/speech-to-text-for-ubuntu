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
export STT_MODEL="${STT_MODEL:-large-v3}"                    # Best quality transcription
export STT_DEVICE="${STT_DEVICE:-cuda}"                      # GPU acceleration
export STT_COMPUTE_TYPE="${STT_COMPUTE_TYPE:-float16}"        # Optimal precision/speed balance
export STT_BEAM_SIZE="${STT_BEAM_SIZE:-5}"                    # Maximum accuracy
export STT_TEMPERATURE="${STT_TEMPERATURE:-0.0}"              # Deterministic output
export STT_VAD="${STT_VAD:-1}"                               # Voice Activity Detection
export STT_CONDITION="${STT_CONDITION:-1}"                    # Text conditioning
export STT_LANGUAGE="${STT_LANGUAGE:-en}"                     # English language

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

# Model Configuration (Best Quality)
export STT_MODEL="large-v3"           # Best accuracy, ~3GB VRAM usage
export STT_DEVICE="cuda"              # GPU acceleration
export STT_COMPUTE_TYPE="float16"     # Optimal precision/speed balance for RTX 4070

# Quality vs Speed Optimization
export STT_BEAM_SIZE="5"              # Maximum accuracy (1-5, 5 = best)
export STT_TEMPERATURE="0.0"          # Deterministic output (0.0 = most accurate)
export STT_VAD="1"                    # Voice Activity Detection enabled
export STT_CONDITION="1"              # Text conditioning enabled
export STT_LANGUAGE="en"              # English language hint

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
# - large-v3: Best accuracy, reasonable speed, ~3GB VRAM usage
# - float16: Good precision, efficient memory usage
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
echo "📝 Output Mode: $STT_MODE (Manual Pasting)"
echo "🧹 Text Cleaning: $STT_CLEAN_TEXT (Enabled)"
echo ""

echo "💡 How to Use:"
echo "   1. Press F16 (or your hotkey) to start recording"
echo "   2. Speak clearly - large-v3 will provide best accuracy"
echo "   3. Text is automatically cleaned and copied to clipboard"
echo "   4. Press Ctrl+V to paste the cleaned text"
echo ""

echo "🔧 Environment Variables Set:"
echo "   STT_MODEL=$STT_MODEL"
echo "   STT_DEVICE=$STT_DEVICE"
echo "   STT_COMPUTE_TYPE=$STT_COMPUTE_TYPE"
echo "   STT_BEAM_SIZE=$STT_BEAM_SIZE"
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
    echo "   Available: $((total - used))MB for large-v3 model"
done

echo ""
echo "🎉 Large-v3 GPU Configuration Ready!"
echo "   Your RTX 4070 is configured for maximum quality transcription!"
