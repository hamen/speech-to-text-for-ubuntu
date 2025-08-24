#!/bin/bash

# Sound Notification Test Script
# Tests the new sound notification system

set -e

echo "🔊 Sound Notification Test"
echo "=========================="
echo ""

# Check if running in virtual environment
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "🔌 Activating virtual environment..."
    source venv/bin/activate
fi

# Load configuration
if [[ -f "./large-v3-config.sh" ]]; then
    echo "📁 Loading large-v3 configuration..."
    source ./large-v3-config.sh
else
    echo "📁 Loading GPU configuration..."
    source ./gpu-config.sh
fi

echo ""
echo "🎵 Current Sound Configuration:"
echo "   STT_USE_SOUND: ${STT_USE_SOUND}"
echo "   STT_SOUND_FILE: ${STT_SOUND_FILE}"
echo "   STT_USE_NOTIFICATION: ${STT_USE_NOTIFICATION}"
echo ""

# Test sound file existence
if [[ -f "$STT_SOUND_FILE" ]]; then
    echo "✅ Sound file found: $STT_SOUND_FILE"
else
    echo "❌ Sound file not found: $STT_SOUND_FILE"
    echo "   Available system sounds:"
    ls /usr/share/sounds/freedesktop/stereo/ | grep -E "(complete|bell|message)" | head -5
fi

echo ""
echo "🔊 Testing sound notification..."
echo "   You should hear a completion sound in 3 seconds..."

# Test the sound notification function
python3 -c "
import sys
import os
sys.path.insert(0, os.getcwd())
from speech_to_text import _play_sound, STT_SOUND_FILE

print(f'Playing sound: {STT_SOUND_FILE}')
_play_sound(STT_SOUND_FILE)
print('Sound played!')
"

echo ""
echo "🎉 Sound notification test completed!"
echo ""
echo "💡 Configuration Options:"
echo "   • Enable sound only: export STT_USE_SOUND=1 && export STT_USE_NOTIFICATION=0"
echo "   • Enable notifications only: export STT_USE_SOUND=0 && export STT_USE_NOTIFICATION=1"
echo "   • Enable both: export STT_USE_SOUND=1 && export STT_USE_NOTIFICATION=1"
echo "   • Custom sound: export STT_SOUND_FILE=/path/to/your/sound.oga"
echo ""
echo "🔊 Available System Sounds:"
ls /usr/share/sounds/freedesktop/stereo/ | grep -E "(complete|bell|message)" | head -10
