#!/bin/bash

# Speech-to-Text for Ubuntu - Automated Setup and Launch Script
# Optimized for NVIDIA RTX 4070 with GPU acceleration

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo "🚀 Speech-to-Text for Ubuntu - GPU Optimized Setup"
echo "=================================================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "✅ Running as root (required for input device access)"
else
    echo "❌ This script must be run as root for input device access"
    echo "   Please run: sudo $0"
    exit 1
fi

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    echo "🎮 NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | while IFS=, read -r name memory; do
        echo "   GPU: $name (${memory}MB VRAM)"
    done
    echo ""

    # Set optimal GPU configuration for RTX 4070
    export STT_DEVICE="cuda"
    export STT_COMPUTE_TYPE="float16"
    export STT_MODEL="large-v3"
    echo "⚡ GPU Configuration:"
    echo "   Device: $STT_DEVICE"
    echo "   Compute Type: $STT_COMPUTE_TYPE"
    echo "   Model: $STT_MODEL"
    echo ""
else
    echo "⚠️  No NVIDIA GPU detected, falling back to CPU"
    export STT_DEVICE="cpu"
    export STT_COMPUTE_TYPE="int8"
    export STT_MODEL="base.en"
fi

# Set text cleaning configuration for optimal results
export STT_CLEAN_TEXT="1"
export STT_REMOVE_FILLERS="1"
export STT_FIX_REPETITIONS="1"
export STT_FIX_PUNCTUATION="1"
export STT_MIN_SENTENCE_WORDS="2"

# Set output mode (clipboard is more reliable)
export STT_MODE="clipboard"

# Other optimization settings
export STT_BEAM_SIZE="5"  # Higher beam size for better accuracy with GPU
export STT_LANGUAGE="en"
export STT_VAD="1"
export STT_CONDITION="1"
export STT_TEMPERATURE="0.0"

echo "🧹 Text Cleaning Configuration:"
echo "   Clean Text: $STT_CLEAN_TEXT"
echo "   Remove Fillers: $STT_REMOVE_FILLERS"
echo "   Fix Repetitions: $STT_FIX_REPETITIONS"
echo "   Fix Punctuation: $STT_FIX_PUNCTUATION"
echo "   Min Sentence Words: $STT_MIN_SENTENCE_WORDS"
echo ""

echo "📝 Output Mode: $STT_MODE"
echo "🎯 Model: $STT_MODEL"
echo "🔧 Beam Size: $STT_BEAM_SIZE"
echo ""

# Install system dependencies based on session type
echo "📦 Installing system dependencies..."
SESSION_TYPE=$(echo $XDG_SESSION_TYPE | tr '[:upper:]' '[:lower:]')
if [[ "$SESSION_TYPE" == "wayland" ]]; then
    echo "🌊 Installing Wayland clipboard tools..."
    apt update -qq && apt install -y wl-clipboard libnotify-bin
elif [[ "$SESSION_TYPE" == "x11" ]] || [[ -n "$DISPLAY" ]]; then
    echo "🖥️  Installing X11 clipboard tools..."
    apt update -qq && apt install -y xclip xsel libnotify-bin
else
    echo "❓ Installing both Wayland and X11 clipboard tools (unknown session type)..."
    apt update -qq && apt install -y wl-clipboard xclip xsel libnotify-bin
fi

# Check if virtual environment exists
if [[ ! -d "venv" ]]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Install/upgrade dependencies
echo "📚 Installing/upgrading dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install CUDA-optimized PyTorch if GPU is available
if [[ "$STT_DEVICE" == "cuda" ]]; then
    echo "🚀 Installing CUDA-optimized PyTorch for GPU acceleration..."
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
fi

# Check if ydotoold is running
if ! pgrep -x "ydotoold" > /dev/null; then
    echo "🔧 Starting ydotoold daemon..."
    ydotoold &
    sleep 2
fi

# Check if input-remapper is running
if ! pgrep -x "input-remapper-control" > /dev/null; then
    echo "🔧 Starting input-remapper..."
    input-remapper-control --command start &
    sleep 2
fi

echo ""
echo "🎯 Launching Speech-to-Text with optimal GPU configuration..."
echo "   Press F16 (or your configured hotkey) to start recording"
echo "   Press Ctrl+C to stop"
echo ""

# Launch the key listener
python3 key_listener.py


