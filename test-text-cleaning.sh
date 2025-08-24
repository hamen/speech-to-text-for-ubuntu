#!/bin/bash

# Text Cleaning Test Script
# Demonstrates the difference between aggressive and conservative cleaning

set -e

echo "🧹 Text Cleaning Test - Conservative vs Aggressive"
echo "=================================================="
echo ""

# Check if running in virtual environment
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "🔌 Activating virtual environment..."
    source venv/bin/activate
fi

# Test cases that were problematic before
test_cases=(
    "Okay, let's try to do this. Now I'm gonna kind of... Oh no, I'm kind of rambling."
    "Um, I I I think that um you know the the the thing is basically um actually"
    "Well, I mean like basically um you know what I'm saying right?"
    "So um I was thinking um you know like kind of maybe we could um try something different"
)

echo "📝 Testing Text Cleaning Modes"
echo "=============================="
echo ""

for i in "${!test_cases[@]}"; do
    test_text="${test_cases[$i]}"
    echo "Test $((i+1)):"
    echo "  Original: \"$test_text\""
    echo ""

    # Test conservative mode (default)
    echo "  Conservative Mode (Default):"
    export STT_AGGRESSIVE_CLEANING="0"
    export STT_PRESERVE_COMMON_WORDS="1"

    python3 -c "
import sys
import os
sys.path.insert(0, os.getcwd())
from speech_to_text import clean_transcribed_text

text = '''$test_text'''
cleaned = clean_transcribed_text(text)
print(f'    \"{cleaned}\"')
"

    echo ""

    # Test aggressive mode
    echo "  Aggressive Mode:"
    export STT_AGGRESSIVE_CLEANING="1"
    export STT_PRESERVE_COMMON_WORDS="0"

    python3 -c "
import sys
import os
sys.path.insert(0, os.getcwd())
from speech_to_text import clean_transcribed_text

text = '''$test_text'''
cleaned = clean_transcribed_text(text)
print(f'    \"{cleaned}\"')
"

    echo ""
    echo "  ----------------------------------------"
    echo ""
done

echo "🎯 Summary of Changes:"
echo "======================"
echo "✅ Conservative Mode (Default):"
echo "   • Keeps meaningful words: 'okay', 'well', 'now'"
echo "   • Only removes obvious speech sounds: 'um', 'uh'"
echo "   • Preserves natural speech patterns"
echo "   • Less aggressive sentence filtering"
echo ""
echo "⚠️  Aggressive Mode:"
echo "   • Removes more filler words: 'like', 'basically', 'kind of'"
echo "   • More aggressive sentence filtering"
echo "   • May remove meaningful content"
echo ""
echo "💡 Current Configuration:"
echo "   STT_AGGRESSIVE_CLEANING: ${STT_AGGRESSIVE_CLEANING:-0}"
echo "   STT_PRESERVE_COMMON_WORDS: ${STT_PRESERVE_COMMON_WORDS:-1}"
echo ""
echo "🔧 To Switch Modes:"
echo "   Conservative: export STT_AGGRESSIVE_CLEANING=0"
echo "   Aggressive:  export STT_AGGRESSIVE_CLEANING=1"
echo ""
echo "🎉 Text cleaning is now much more intelligent and conservative!"
