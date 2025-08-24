#!/bin/bash

# GPU-Optimized Configuration for Speech-to-Text
# Optimized for NVIDIA RTX 4070 (12GB VRAM)

# =============================================================================
# WHISPER MODEL CONFIGURATION
# =============================================================================

# Model Selection (choose one)
# Uncomment your preferred model:

# 🏆 BEST QUALITY (Recommended for RTX 4070)
export STT_MODEL="large-v3"           # Best accuracy, ~3GB VRAM usage
                                      # Excellent for professional use, high accuracy
                                      # Good balance of quality and speed

# 🚀 BALANCED OPTIONS
# export STT_MODEL="large-v2"        # Alternative to large-v3, ~3GB VRAM
# export STT_MODEL="large"           # Original large model, ~3GB VRAM
# export STT_MODEL="medium.en"       # Good balance, ~1.5GB VRAM usage
                                      # Faster than large models, still good quality
                                      # Great for real-time applications

# ⚡ SPEED OPTIMIZED
# export STT_MODEL="small.en"        # Fast, ~0.5GB VRAM usage
                                      # Good for real-time, decent quality
# export STT_MODEL="base.en"         # Very fast, ~0.25GB VRAM usage
                                      # Fastest, basic quality
# export STT_MODEL="tiny.en"         # Fastest, ~0.1GB VRAM usage
                                      # Fastest, basic quality, good for testing

# GPU Configuration
export STT_DEVICE="cuda"              # Use CUDA GPU acceleration
export STT_COMPUTE_TYPE="float16"     # Optimal for RTX 4070 (good accuracy + speed)
                                      # Alternative: "float32" for maximum precision (slower)

# Quality vs Speed Trade-offs
export STT_BEAM_SIZE="5"              # Higher = better accuracy, slower (1-5 recommended)
                                      # 1 = fastest, 5 = best accuracy
export STT_TEMPERATURE="0.0"          # 0.0 = deterministic, higher = more creative
export STT_VAD="1"                    # Voice Activity Detection (1 = enabled)
export STT_CONDITION="1"              # Text conditioning (1 = enabled)
export STT_LANGUAGE="en"              # Language hint for transcription

# =============================================================================
# TEXT CLEANING CONFIGURATION
# =============================================================================

# Enable/Disable Text Cleaning
export STT_CLEAN_TEXT="1"             # 1 = enabled, 0 = disabled

# Cleaning Options
export STT_REMOVE_FILLERS="1"         # Remove "um", "uh", "you know" (conservative)
export STT_FIX_REPETITIONS="1"        # Fix stuttering and word repetitions
export STT_FIX_PUNCTUATION="1"        # Clean up excessive punctuation
export STT_MIN_SENTENCE_WORDS="2"     # Minimum words for a sentence to be kept
export STT_AGGRESSIVE_CLEANING="0"    # 0 = conservative, 1 = aggressive
export STT_PRESERVE_COMMON_WORDS="1"  # Preserve meaningful words like "okay", "well"

# =============================================================================
# OUTPUT MODE
# =============================================================================

export STT_MODE="clipboard"           # "clipboard" or "type"
                                      # clipboard = copy to clipboard + notification
                                      # type = automatic typing (may be blocked on Wayland)

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
