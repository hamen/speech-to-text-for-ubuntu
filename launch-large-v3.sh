#!/bin/bash

# Large-v3 GPU Launcher for Speech-to-Text
# Optimized for RTX 4070 with manual pasting and post-processing

set -e

echo "🚀 Launching Large-v3 GPU Speech-to-Text System"
echo "================================================"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "✅ Running as root (required for input device access)"
else
    echo "❌ This script must be run as root for input device access"
    echo "   Please run: sudo $0"
    exit 1
fi

# Load large-v3 configuration
echo "⚙️  Loading Large-v3 GPU Configuration..."
source ./large-v3-config.sh

# Verify GPU is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA GPU not detected"
    echo "   This configuration requires GPU acceleration"
    exit 1
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

# Install CUDA-optimized PyTorch for GPU acceleration
echo "🚀 Installing CUDA-optimized PyTorch for GPU acceleration..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

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

# Show final configuration
echo ""
echo "🎯 Final Configuration:"
echo "======================="
echo "   Model: $STT_MODEL"
echo "   Device: $STT_DEVICE"
echo "   Compute Type: $STT_COMPUTE_TYPE"
echo "   Beam Size: $STT_BEAM_SIZE"
echo "   Output Mode: $STT_MODE"
echo "   Text Cleaning: $STT_CLEAN_TEXT"
echo ""

# Check GPU memory before launch
echo "🎮 GPU Memory Check:"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | while IFS=, read -r used total; do
    available=$((total - used))
    echo "   Available: ${available}MB / Total: ${total}MB"
    if [[ $available -lt 3000 ]]; then
        echo "   ⚠️  Low GPU memory - consider closing other applications"
    else
        echo "   ✅ Sufficient memory for large-v3 model (~3GB required)"
    fi
done

echo ""
echo "🎯 Launching Large-v3 Speech-to-Text System..."
echo "   Press F16 (or your configured hotkey) to start recording"
echo "   Press Ctrl+C to stop"
echo ""
echo "💡 Features:"
echo "   • Best quality transcription with large-v3 model"
echo "   • GPU acceleration for fast processing"
echo "   • Intelligent text cleaning (removes fillers, fixes stuttering)"
echo "   • Manual pasting mode (reliable clipboard + notification)"
echo ""

# Launch the key listener with large-v3 configuration
python3 key_listener.py
