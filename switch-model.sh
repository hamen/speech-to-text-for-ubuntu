#!/bin/bash

# Whisper Model Switcher
# Easy switching between different models for testing

set -e

# Available models
models=("tiny.en" "base.en" "small.en" "medium.en" "large-v3" "large-v2" "large")

# Function to show current configuration
show_current() {
    echo "🔧 Current Configuration:"
    echo "   Model: ${STT_MODEL:-'Not set'}"
    echo "   Device: ${STT_DEVICE:-'Not set'}"
    echo "   Compute Type: ${STT_COMPUTE_TYPE:-'Not set'}"
    echo "   Beam Size: ${STT_BEAM_SIZE:-'Not set'}"
    echo ""
}

# Function to switch to a specific model
switch_model() {
    local model=$1
    local device=${2:-"cuda"}
    local compute_type=${3:-"float16"}

    echo "🔄 Switching to $model..."

    # Set environment variables
    export STT_MODEL="$model"
    export STT_DEVICE="$device"
    export STT_COMPUTE_TYPE="$compute_type"

    # Set optimal beam size based on model
    case $model in
        "tiny.en"|"base.en")
            export STT_BEAM_SIZE="1"
            ;;
        "small.en"|"medium.en")
            export STT_BEAM_SIZE="3"
            ;;
        "large-v3"|"large-v2"|"large")
            export STT_BEAM_SIZE="5"
            ;;
    esac

    echo "✅ Switched to $model"
    echo "   Device: $STT_DEVICE"
    echo "   Compute Type: $STT_COMPUTE_TYPE"
    echo "   Beam Size: $STT_BEAM_SIZE"
    echo ""
}

# Function to show model comparison
show_comparison() {
    echo "📊 Model Comparison for RTX 4070:"
    echo "=================================="
    printf "%-12s | %-8s | %-8s | %-12s | %s\n" "Model" "VRAM" "Speed" "Quality" "Best For"
    echo "------------|----------|----------|--------------|------------------"
    printf "%-12s | %-8s | %-8s | %-12s | %s\n" "tiny.en" "0.1GB" "⚡⚡⚡⚡⚡" "🟡 Basic" "Testing, speed"
    printf "%-12s | %-8s | %-8s | %-12s | %s\n" "base.en" "0.25GB" "⚡⚡⚡⚡" "🟡 Basic" "Speed priority"
    printf "%-12s | %-8s | %-8s | %-12s | %s\n" "small.en" "0.5GB" "⚡⚡⚡" "🟢 Good" "Balanced"
    printf "%-12s | %-8s | %-8s | %-12s | %s\n" "medium.en" "1.5GB" "⚡⚡" "🟢 Very Good" "Real-time"
    printf "%-12s | %-8s | %-8s | %-12s | %s\n" "large-v3" "3GB" "⚡" "🔴 Excellent" "Best quality"
    printf "%-12s | %-8s | %-8s | %-12s | %s\n" "large-v2" "3GB" "⚡" "🔴 Excellent" "Alternative"
    printf "%-12s | %-8s | %-8s | %-12s | %s\n" "large" "3GB" "⚡" "🔴 Excellent" "Original"
    echo ""
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --model MODEL    Switch to specific model"
    echo "  -l, --list          List available models"
    echo "  -c, --current       Show current configuration"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -m large-v3      # Switch to large-v3 (best quality)"
    echo "  $0 -m medium.en     # Switch to medium.en (balanced)"
    echo "  $0 -m tiny.en       # Switch to tiny.en (fastest)"
    echo "  $0 -c               # Show current config"
    echo "  $0 -l               # List all models"
    echo ""
    echo "Models: ${models[*]}"
}

# Main script logic
case "${1:-}" in
    -m|--model)
        if [[ -z "$2" ]]; then
            echo "❌ Error: Model name required"
            echo "Available models: ${models[*]}"
            exit 1
        fi

        # Check if model is valid
        if [[ " ${models[*]} " =~ " $2 " ]]; then
            switch_model "$2"
            show_current
        else
            echo "❌ Error: Invalid model '$2'"
            echo "Available models: ${models[*]}"
            exit 1
        fi
        ;;
    -l|--list)
        show_comparison
        ;;
    -c|--current)
        show_current
        ;;
    -h|--help|"")
        show_usage
        ;;
    *)
        echo "❌ Error: Unknown option '$1'"
        show_usage
        exit 1
        ;;
esac

# Export variables for immediate use
if [[ -n "$STT_MODEL" ]]; then
    echo "💡 To use this configuration:"
    echo "   export STT_MODEL='$STT_MODEL'"
    echo "   export STT_DEVICE='$STT_DEVICE'"
    echo "   export STT_COMPUTE_TYPE='$STT_COMPUTE_TYPE'"
    echo "   export STT_BEAM_SIZE='$STT_BEAM_SIZE'"
    echo ""
    echo "🚀 Or run: source gpu-config.sh"
fi
