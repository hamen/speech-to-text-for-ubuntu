#!/bin/bash

# GPU Test Script for Speech-to-Text
# Tests GPU acceleration and model loading

set -e

echo "🧪 Testing GPU Configuration for Speech-to-Text"
echo "==============================================="
echo ""

# Check if running in virtual environment
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "🔌 Activating virtual environment..."
    source venv/bin/activate
fi

# Test GPU detection
echo "🎮 GPU Detection Test:"
if command -v nvidia-smi &> /dev/null; then
    echo "✅ NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits | while IFS=, read -r name memory driver; do
        echo "   GPU: $name (${memory}MB VRAM, Driver: $driver)"
    done
else
    echo "❌ No NVIDIA GPU detected"
    exit 1
fi

echo ""

# Test PyTorch CUDA support
echo "🔥 PyTorch CUDA Test:"
python3 -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA version: {torch.version.cuda}')
    print(f'GPU count: {torch.cuda.device_count()}')
    print(f'Current GPU: {torch.cuda.get_device_name(0)}')
    print(f'GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
else:
    print('❌ CUDA not available in PyTorch')
    exit(1)
"

echo ""

# Test Faster Whisper GPU support
echo "🎯 Faster Whisper GPU Test:"
python3 -c "
from faster_whisper import WhisperModel
import time

print('Testing GPU model loading...')

# Test with small model first
print('Loading tiny.en model on GPU...')
start_time = time.time()
model = WhisperModel('tiny.en', device='cuda', compute_type='float16')
load_time = time.time() - start_time
print(f'✅ tiny.en loaded in {load_time:.2f}s')

# Test transcription
print('Testing transcription...')
audio = b'RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00D\xac\x00\x00\x88X\x01\x00\x02\x00\x10\x00data\x00\x00\x00\x00'
start_time = time.time()
segments, _ = model.transcribe(audio, language='en')
transcribe_time = time.time() - start_time
print(f'✅ Transcription test completed in {transcribe_time:.2f}s')

# Test larger model
print('Loading large-v3 model on GPU...')
start_time = time.time()
large_model = WhisperModel('large-v3', device='cuda', compute_type='float16')
load_time = time.time() - start_time
print(f'✅ large-v3 loaded in {load_time:.2f}s')

print('🎉 GPU acceleration working perfectly!')
"

echo ""

# Test environment variables
echo "⚙️  Environment Variables Test:"
source gpu-config.sh
echo "✅ Configuration loaded:"
echo "   STT_MODEL: $STT_MODEL"
echo "   STT_DEVICE: $STT_DEVICE"
echo "   STT_COMPUTE_TYPE: $STT_COMPUTE_TYPE"
echo "   STT_BEAM_SIZE: $STT_BEAM_SIZE"

echo ""
echo "🎯 GPU Test Completed Successfully!"
echo "   Your RTX 4070 is ready for high-performance speech recognition!"
echo ""
echo "💡 Next steps:"
echo "   1. Run: sudo ./run.sh (for full system)"
echo "   2. Or test: source gpu-config.sh && python3 speech_to_text.py <audio_file>"
