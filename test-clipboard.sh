#!/bin/bash

# Test clipboard functionality for different desktop environments
# This script helps diagnose clipboard issues on X11 vs Wayland

set -e

echo "🔍 Clipboard Detection Test"
echo "============================"
echo ""

# Check session type
SESSION_TYPE=$(echo $XDG_SESSION_TYPE | tr '[:upper:]' '[:lower:]')
echo "📊 Session Information:"
echo "   XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-'not set'}"
echo "   DISPLAY: ${DISPLAY:-'not set'}"
echo "   WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-'not set'}"
echo "   Detected session: ${SESSION_TYPE:-'unknown'}"
echo ""

# Check available clipboard tools
echo "🛠️  Available Clipboard Tools:"
echo "   wl-copy (Wayland): $(command -v wl-copy 2>/dev/null && echo '✅ installed' || echo '❌ not found')"
echo "   xclip (X11): $(command -v xclip 2>/dev/null && echo '✅ installed' || echo '❌ not found')"
echo "   xsel (X11): $(command -v xsel 2>/dev/null && echo '✅ installed' || echo '❌ not found')"
echo ""

# Test clipboard functionality
echo "🧪 Clipboard Functionality Test:"
TEST_TEXT="Hello from clipboard test! $(date)"

if [[ "$SESSION_TYPE" == "wayland" ]]; then
    echo "🌊 Testing Wayland clipboard (wl-copy)..."
    if command -v wl-copy &> /dev/null; then
        echo "$TEST_TEXT" | wl-copy 2>/dev/null && echo "✅ wl-copy: Success" || echo "❌ wl-copy: Failed"
    else
        echo "❌ wl-copy: Not installed"
    fi
elif [[ "$SESSION_TYPE" == "x11" ]] || [[ -n "$DISPLAY" ]]; then
    echo "🖥️  Testing X11 clipboard tools..."
    if command -v xclip &> /dev/null; then
        echo "$TEST_TEXT" | xclip -selection clipboard 2>/dev/null && echo "✅ xclip: Success" || echo "❌ xclip: Failed"
    else
        echo "❌ xclip: Not installed"
    fi
    if command -v xsel &> /dev/null; then
        echo "$TEST_TEXT" | xsel --clipboard --input 2>/dev/null && echo "✅ xsel: Success" || echo "❌ xsel: Failed"
    else
        echo "❌ xsel: Not installed"
    fi
else
    echo "❓ Unknown session type, testing all tools..."
    if command -v wl-copy &> /dev/null; then
        echo "$TEST_TEXT" | wl-copy 2>/dev/null && echo "✅ wl-copy: Success" || echo "❌ wl-copy: Failed"
    fi
    if command -v xclip &> /dev/null; then
        echo "$TEST_TEXT" | xclip -selection clipboard 2>/dev/null && echo "✅ xclip: Success" || echo "❌ xclip: Failed"
    fi
    if command -v xsel &> /dev/null; then
        echo "$TEST_TEXT" | xsel --clipboard --input 2>/dev/null && echo "✅ xsel: Success" || echo "❌ xsel: Failed"
    fi
fi

echo ""
echo "💡 Recommendations:"
if [[ "$SESSION_TYPE" == "wayland" ]]; then
    if ! command -v wl-copy &> /dev/null; then
        echo "   Install Wayland clipboard tools: sudo apt install wl-clipboard"
    fi
elif [[ "$SESSION_TYPE" == "x11" ]] || [[ -n "$DISPLAY" ]]; then
    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        echo "   Install X11 clipboard tools: sudo apt install xclip xsel"
    fi
fi

echo ""
echo "🎯 Test completed!"
