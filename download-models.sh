#!/bin/bash

# Whisper Model Downloader and Tester
# Optimized for NVIDIA RTX 4070 (12GB VRAM)

set -e

echo "🚀 Whisper Model Downloader for RTX 4070"
echo "========================================="
echo ""

# Check if running in virtual environment
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "🔌 Activating virtual environment..."
    source venv/bin/activate
fi

# Check GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ No NVIDIA GPU detected"
    exit 1
fi

echo "🎮 GPU Detected:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | while IFS=, read -r name memory; do
    echo "   $name (${memory}MB VRAM)"
done
echo ""

# Available models with VRAM requirements and quality ratings
declare -A models=(
    ["tiny.en"]="0.1GB|Fastest|Basic accuracy|Good for real-time"
    ["base.en"]="0.25GB|Very fast|Basic accuracy|Good for real-time"
    ["small.en"]="0.5GB|Fast|Good accuracy|Balanced speed/quality"
    ["medium.en"]="1.5GB|Medium|Very good accuracy|Recommended balance"
    ["large-v3"]="3GB|Medium-slow|Excellent accuracy|Best quality/speed ratio"
    ["large-v2"]="3GB|Medium-slow|Excellent accuracy|Alternative to large-v3"
    ["large"]="3GB|Medium-slow|Excellent accuracy|Original large model"
)

# Function to test model loading and performance
test_model() {
    local model_name=$1
    local device=${2:-"cuda"}
    local compute_type=${3:-"float16"}

    echo "🧪 Testing $model_name on $device..."

    python3 -c "
import time
import psutil
import GPUtil
from faster_whisper import WhisperModel

try:
    # Get initial memory
    if '$device' == 'cuda':
        gpu = GPUtil.getGPUs()[0]
        initial_memory = gpu.memoryUsed
        print(f'Initial GPU memory: {initial_memory:.1f}MB')

    # Load model
    print('Loading model...')
    start_time = time.time()
    model = WhisperModel('$model_name', device='$device', compute_type='$compute_type')
    load_time = time.time() - start_time

    # Check memory usage
    if '$device' == 'cuda':
        gpu = GPUtil.getGPUs()[0]
        final_memory = gpu.memoryUsed
        memory_used = final_memory - initial_memory
        print(f'Model loaded in {load_time:.2f}s')
        print(f'GPU memory used: {memory_used:.1f}MB')
        print(f'Total GPU memory: {gpu.memoryUsed:.1f}MB / {gpu.memoryTotal:.1f}MB')
    else:
        print(f'Model loaded in {load_time:.2f}s')

    # Test transcription with dummy audio
    print('Testing transcription...')
    dummy_audio = b'RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00D\xac\x00\x00\x88X\x01\x00\x02\x00\x10\x00data\x00\x00\x00\x00'

    start_time = time.time()
    segments, _ = model.transcribe(dummy_audio, language='en')
    transcribe_time = time.time() - start_time

    print(f'✅ $model_name working perfectly!')
    print(f'   Load time: {load_time:.2f}s')
    print(f'   Transcribe time: {transcribe_time:.2f}s')

except Exception as e:
    print(f'❌ Error with $model_name: {e}')
    exit(1)
"
}

# Function to download and test a model
download_and_test_model() {
    local model_name=$1
    local device=${2:-"cuda"}
    local compute_type=${3:-"float16"}

    echo ""
    echo "📥 Downloading and testing $model_name..."
    echo "=========================================="

    # Test if model can be loaded
    if test_model "$model_name" "$device" "$compute_type"; then
        echo "✅ $model_name is ready to use!"
        return 0
    else
        echo "❌ Failed to load $model_name"
        return 1
    fi
}

# Show available models
echo "📋 Available Whisper Models:"
echo "============================"
for model in "${!models[@]}"; do
    IFS='|' read -r vram speed quality description <<< "${models[$model]}"
    printf "%-12s | %-8s | %-6s | %s\n" "$model" "$vram" "$quality" "$description"
done

echo ""
echo "🎯 Recommended Models for RTX 4070:"
echo "==================================="
echo "1. large-v3    - Best accuracy/speed ratio (3GB VRAM)"
echo "2. medium.en   - Good balance for real-time (1.5GB VRAM)"
echo "3. small.en    - Fast with decent quality (0.5GB VRAM)"
echo ""

# Install required packages for testing
echo "📦 Installing required packages for testing..."
pip install psutil GPUtil

# Test current models
echo "🧪 Testing Current Models..."
echo "============================"

# Test tiny.en first (should be fastest)
if download_and_test_model "tiny.en" "cuda" "float16"; then
    echo "✅ tiny.en ready"
else
    echo "❌ tiny.en failed"
fi

# Test medium.en (good balance)
if download_and_test_model "medium.en" "cuda" "float16"; then
    echo "✅ medium.en ready"
else
    echo "❌ medium.en failed"
fi

# Test large-v3 (best quality)
if download_and_test_model "large-v3" "cuda" "float16"; then
    echo "✅ large-v3 ready"
else
    echo "❌ large-v3 failed"
fi

echo ""
echo "🎉 Model Testing Complete!"
echo ""
echo "💡 Next Steps:"
echo "   1. Use gpu-config.sh to switch between models"
echo "   2. Test different models: export STT_MODEL=medium.en"
echo "   3. Compare quality vs speed for your use case"
echo ""
echo "📊 Model Performance Summary:"
echo "   tiny.en: Fastest, basic quality"
echo "   medium.en: Balanced, good quality"
echo "   large-v3: Best quality, reasonable speed"
echo ""
echo "🔧 To use a specific model:"
echo "   export STT_MODEL=large-v3 && python3 speech_to_text.py <audio>"
