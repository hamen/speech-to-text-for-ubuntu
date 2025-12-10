#!/bin/bash

# Configuration Manager for Speech-to-Text
# Handles saving and loading user preferences

set -e

CONFIG_FILE="$HOME/.config/speech-to-text/config.conf"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"

# Default configuration values
DEFAULT_CONFIG=(
    "STT_USE_SOUND=1"
    "STT_USE_NOTIFICATION=0"
    "STT_SOUND_FILE=/usr/share/sounds/freedesktop/stereo/complete.oga"
    "STT_AGGRESSIVE_CLEANING=0"
    "STT_PRESERVE_COMMON_WORDS=1"
    "STT_MODE=clipboard"
    "STT_MODEL=large-v3"
    "STT_DEVICE=cuda"
    "STT_COMPUTE_TYPE=float16"
    "STT_BEAM_SIZE=5"
    "STT_ENABLE_DOUBLE_SUPER=0"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
show_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Initialize configuration directory and file
init_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        show_info "Created configuration directory: $CONFIG_DIR"
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        # Create default configuration
        for setting in "${DEFAULT_CONFIG[@]}"; do
            echo "$setting" >> "$CONFIG_FILE"
        done
        show_success "Created default configuration file: $CONFIG_FILE"
    fi
}

# Load configuration from file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        show_info "Loading configuration from: $CONFIG_FILE"
        source "$CONFIG_FILE"
        show_success "Configuration loaded successfully"
    else
        show_warning "Configuration file not found, using defaults"
        init_config
        source "$CONFIG_FILE"
    fi
}

# Save configuration to file
save_config() {
    local key="$1"
    local value="$2"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        init_config
    fi

    # Update or add the setting
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        # Update existing setting
        sed -i "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
    else
        # Add new setting
        echo "${key}=${value}" >> "$CONFIG_FILE"
    fi

    show_success "Saved: ${key}=${value}"
}

# Show current configuration
show_config() {
    echo ""
    echo "🔧 Current Configuration:"
    echo "========================="

    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            if [[ -n "$key" && ! "$key" =~ ^# ]]; then
                echo "   $key: $value"
            fi
        done < "$CONFIG_FILE"
    else
        show_warning "No configuration file found"
    fi
}

# Interactive configuration menu
config_menu() {
    while true; do
        echo ""
        echo "⚙️  Configuration Menu"
        echo "====================="
        echo "1️⃣  Sound vs Notification Settings"
        echo "2️⃣  Text Cleaning Settings"
        echo "3️⃣  Model & Performance Settings"
        echo "4️⃣  Hotkey Settings"
        echo "5️⃣  Show Current Configuration"
        echo "6️⃣  Reset to Defaults"
        echo "7️⃣  Back to Main Menu"
        echo ""

        local choice=$(gum choose "1️⃣ Sound/Notification" "2️⃣ Text Cleaning" "3️⃣ Model Settings" "4️⃣ Hotkey Settings" "5️⃣ Show Config" "6️⃣ Reset Defaults" "7️⃣ Back")

        case "$choice" in
            "1️⃣ Sound/Notification")
                sound_notification_menu
                ;;
            "2️⃣ Text Cleaning")
                text_cleaning_menu
                ;;
            "3️⃣ Model Settings")
                model_settings_menu
                ;;
            "4️⃣ Hotkey Settings")
                hotkey_settings_menu
                ;;
            "5️⃣ Show Config")
                show_config
                ;;
            "6️⃣ Reset Defaults")
                reset_config
                ;;
            "7️⃣ Back")
                break
                ;;
        esac
    done
}

# Sound vs Notification configuration menu
sound_notification_menu() {
    while true; do
        echo ""
        echo "🔊 Sound vs Notification Settings"
        echo "================================="
        echo "Current: Sound=${STT_USE_SOUND:-1}, Notification=${STT_USE_NOTIFICATION:-0}"
        echo ""
        echo "1️⃣  Enable Sound Only (Recommended)"
        echo "2️⃣  Enable Notification Only"
        echo "3️⃣  Enable Both"
        echo "4️⃣  Disable Both"
        echo "5️⃣  Custom Sound File"
        echo "6️⃣  Back"
        echo ""

        local choice=$(gum choose "1️⃣ Sound Only" "2️⃣ Notification Only" "3️⃣ Both" "4️⃣ Disable Both" "5️⃣ Custom Sound" "6️⃣ Back")

        case "$choice" in
            "1️⃣ Sound Only")
                save_config "STT_USE_SOUND" "1"
                save_config "STT_USE_NOTIFICATION" "0"
                export STT_USE_SOUND=1
                export STT_USE_NOTIFICATION=0
                show_success "Sound notifications enabled, desktop notifications disabled"
                ;;
            "2️⃣ Notification Only")
                save_config "STT_USE_SOUND" "0"
                save_config "STT_USE_NOTIFICATION" "1"
                export STT_USE_SOUND=0
                export STT_USE_NOTIFICATION=1
                show_success "Desktop notifications enabled, sound notifications disabled"
                ;;
            "3️⃣ Both")
                save_config "STT_USE_SOUND" "1"
                save_config "STT_USE_NOTIFICATION" "1"
                export STT_USE_SOUND=1
                export STT_USE_NOTIFICATION=1
                show_success "Both sound and desktop notifications enabled"
                ;;
            "4️⃣ Disable Both")
                save_config "STT_USE_SOUND" "0"
                save_config "STT_USE_NOTIFICATION" "0"
                export STT_USE_SOUND=0
                export STT_USE_NOTIFICATION=0
                show_success "Both sound and desktop notifications disabled"
                ;;
            "5️⃣ Custom Sound")
                custom_sound_menu
                ;;
            "6️⃣ Back")
                break
                ;;
        esac
    done
}

# Hotkey configuration menu
hotkey_settings_menu() {
    while true; do
        echo ""
        echo "🎹 Hotkey Settings"
        echo "=================="
        echo "Current: Double-Super=${STT_ENABLE_DOUBLE_SUPER:-0} (1 = enabled, 0 = disabled)"
        echo ""

        local choice=$(gum choose "Enable Double-Super" "Disable Double-Super" "Back")

        case "$choice" in
            "Enable Double-Super")
                save_config "STT_ENABLE_DOUBLE_SUPER" "1"
                export STT_ENABLE_DOUBLE_SUPER=1
                show_success "Double-Super hotkey enabled"
                ;;
            "Disable Double-Super")
                save_config "STT_ENABLE_DOUBLE_SUPER" "0"
                export STT_ENABLE_DOUBLE_SUPER=0
                show_success "Double-Super hotkey disabled (recommended)"
                ;;
            "Back")
                break
                ;;
        esac
    done
}

# Custom sound file selection menu
custom_sound_menu() {
    echo ""
    echo "🎵 Custom Sound File Selection"
    echo "=============================="
    echo "Available system sounds:"

    local sounds=()
    while IFS= read -r sound; do
        if [[ -n "$sound" ]]; then
            sounds+=("$sound")
        fi
    done < <(ls /usr/share/sounds/freedesktop/stereo/ | grep -E "(complete|bell|message)")

    if [[ ${#sounds[@]} -eq 0 ]]; then
        show_warning "No system sounds found"
        return
    fi

    echo ""
    local choice=$(gum choose "${sounds[@]}" "Custom Path" "Back")

    if [[ "$choice" == "Custom Path" ]]; then
        echo ""
        echo "Enter custom sound file path:"
        read -r custom_path
        if [[ -f "$custom_path" ]]; then
            save_config "STT_SOUND_FILE" "$custom_path"
            export STT_SOUND_FILE="$custom_path"
            show_success "Custom sound file set: $custom_path"
        else
            show_error "File not found: $custom_path"
        fi
    elif [[ "$choice" == "Back" ]]; then
        return
    else
        local sound_path="/usr/share/sounds/freedesktop/stereo/$choice"
        save_config "STT_SOUND_FILE" "$sound_path"
        export STT_SOUND_FILE="$sound_path"
        show_success "Sound file set: $sound_path"
    fi
}

# Text cleaning configuration menu
text_cleaning_menu() {
    while true; do
        echo ""
        echo "🧹 Text Cleaning Settings"
        echo "========================="
        echo "Current: Aggressive=${STT_AGGRESSIVE_CLEANING:-0}, Preserve=${STT_PRESERVE_COMMON_WORDS:-1}"
        echo ""
        echo "1️⃣  Conservative Mode (Default)"
        echo "2️⃣  Aggressive Mode"
        echo "3️⃣  Customize Individual Settings"
        echo "4️⃣  Back"
        echo ""

        local choice=$(gum choose "1️⃣ Conservative" "2️⃣ Aggressive" "3️⃣ Customize" "4️⃣ Back")

        case "$choice" in
            "1️⃣ Conservative")
                save_config "STT_AGGRESSIVE_CLEANING" "0"
                save_config "STT_PRESERVE_COMMON_WORDS" "1"
                export STT_AGGRESSIVE_CLEANING=0
                export STT_PRESERVE_COMMON_WORDS=1
                show_success "Conservative text cleaning enabled"
                ;;
            "2️⃣ Aggressive")
                save_config "STT_AGGRESSIVE_CLEANING" "1"
                save_config "STT_PRESERVE_COMMON_WORDS" "0"
                export STT_AGGRESSIVE_CLEANING=1
                export STT_PRESERVE_COMMON_WORDS=0
                show_success "Aggressive text cleaning enabled"
                ;;
            "3️⃣ Customize")
                customize_text_cleaning
                ;;
            "4️⃣ Back")
                break
                ;;
        esac
    done
}

# Customize individual text cleaning settings
customize_text_cleaning() {
    while true; do
        echo ""
        echo "🔧 Individual Text Cleaning Settings"
        echo "==================================="
        echo "1️⃣  Toggle Aggressive Cleaning (Current: ${STT_AGGRESSIVE_CLEANING:-0})"
        echo "2️⃣  Toggle Preserve Common Words (Current: ${STT_PRESERVE_COMMON_WORDS:-1})"
        echo "3️⃣  Back"
        echo ""

        local choice=$(gum choose "1️⃣ Toggle Aggressive" "2️⃣ Toggle Preserve" "3️⃣ Back")

        case "$choice" in
            "1️⃣ Toggle Aggressive")
                local new_value=$((1 - ${STT_AGGRESSIVE_CLEANING:-0}))
                save_config "STT_AGGRESSIVE_CLEANING" "$new_value"
                export STT_AGGRESSIVE_CLEANING="$new_value"
                show_success "Aggressive cleaning: $new_value"
                ;;
            "2️⃣ Toggle Preserve")
                local new_value=$((1 - ${STT_PRESERVE_COMMON_WORDS:-1}))
                save_config "STT_PRESERVE_COMMON_WORDS" "$new_value"
                export STT_PRESERVE_COMMON_WORDS="$new_value"
                show_success "Preserve common words: $new_value"
                ;;
            "3️⃣ Back")
                break
                ;;
        esac
    done
}

# Model and performance settings menu
model_settings_menu() {
    while true; do
        echo ""
        echo "🚀 Model & Performance Settings"
        echo "==============================="
        echo "Current: Model=${STT_MODEL:-large-v3}, Device=${STT_DEVICE:-cuda}, Beam=${STT_BEAM_SIZE:-5}"
        echo ""
        echo "1️⃣  Model Selection"
        echo "2️⃣  Device Selection"
        echo "3️⃣  Beam Size Adjustment"
        echo "4️⃣  Output Mode"
        echo "5️⃣  Back"
        echo ""

        local choice=$(gum choose "1️⃣ Model" "2️⃣ Device" "3️⃣ Beam Size" "4️⃣ Output Mode" "5️⃣ Back")

        case "$choice" in
            "1️⃣ Model")
                model_selection_menu
                ;;
            "2️⃣ Device")
                device_selection_menu
                ;;
            "3️⃣ Beam Size")
                beam_size_menu
                ;;
            "4️⃣ Output Mode")
                output_mode_menu
                ;;
            "5️⃣ Back")
                break
                ;;
        esac
    done
}

# Model selection menu
model_selection_menu() {
    echo ""
    echo "📊 Model Selection"
    echo "=================="
    echo "Current: ${STT_MODEL:-large-v3}"
    echo ""

    local models=("tiny.en" "base.en" "small.en" "medium.en" "large-v3" "large-v2" "large")
    local choice=$(gum choose "${models[@]}" "Back")

    if [[ "$choice" != "Back" ]]; then
        save_config "STT_MODEL" "$choice"
        export STT_MODEL="$choice"
        show_success "Model set to: $choice"
    fi
}

# Device selection menu
device_selection_menu() {
    echo ""
    echo "💻 Device Selection"
    echo "==================="
    echo "Current: ${STT_DEVICE:-cuda}"
    echo ""

    local devices=("cuda" "cpu" "auto")
    local choice=$(gum choose "${devices[@]}" "Back")

    if [[ "$choice" != "Back" ]]; then
        save_config "STT_DEVICE" "$choice"
        export STT_DEVICE="$choice"
        show_success "Device set to: $choice"
    fi
}

# Beam size adjustment menu
beam_size_menu() {
    echo ""
    echo "🎯 Beam Size Adjustment"
    echo "======================="
    echo "Current: ${STT_BEAM_SIZE:-5}"
    echo "Higher = Better accuracy, slower processing"
    echo ""

    local beam_sizes=("1" "3" "5" "7" "10")
    local choice=$(gum choose "${beam_sizes[@]}" "Back")

    if [[ "$choice" != "Back" ]]; then
        save_config "STT_BEAM_SIZE" "$choice"
        export STT_BEAM_SIZE="$choice"
        show_success "Beam size set to: $choice"
    fi
}

# Output mode menu
output_mode_menu() {
    echo ""
    echo "📤 Output Mode Selection"
    echo "========================"
    echo "Current: ${STT_MODE:-clipboard}"
    echo ""

    local modes=("clipboard" "type")
    local choice=$(gum choose "${modes[@]}" "Back")

    if [[ "$choice" != "Back" ]]; then
        save_config "STT_MODE" "$choice"
        export STT_MODE="$choice"
        show_success "Output mode set to: $choice"
    fi
}

# Reset configuration to defaults
reset_config() {
    echo ""
    echo "⚠️  Reset Configuration to Defaults"
    echo "==================================="
    echo "This will reset all settings to their default values."
    echo "Are you sure you want to continue?"

    local confirm=$(gum choose "Yes, reset to defaults" "No, keep current settings")

    if [[ "$confirm" == "Yes, reset to defaults" ]]; then
        rm -f "$CONFIG_FILE"
        init_config
        source "$CONFIG_FILE"
        show_success "Configuration reset to defaults"
    else
        show_info "Configuration reset cancelled"
    fi
}

# Export configuration to environment
export_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            if [[ -n "$key" && ! "$key" =~ ^# ]]; then
                export "$key"="$value"
            fi
        done < "$CONFIG_FILE"
    fi
}

# Main function
main() {
    case "${1:-}" in
        "init")
            init_config
            ;;
        "load")
            load_config
            ;;
        "save")
            if [[ $# -eq 3 ]]; then
                save_config "$2" "$3"
            else
                show_error "Usage: $0 save <key> <value>"
                exit 1
            fi
            ;;
        "show")
            show_config
            ;;
        "export")
            export_config
            ;;
        "menu")
            init_config
            load_config
            config_menu
            ;;
        *)
            echo "Usage: $0 {init|load|save|show|export|menu}"
            echo ""
            echo "Commands:"
            echo "  init    - Initialize configuration file with defaults"
            echo "  load    - Load configuration from file"
            echo "  save    - Save a configuration key-value pair"
            echo "  show    - Show current configuration"
            echo "  export  - Export configuration to environment variables"
            echo "  menu    - Interactive configuration menu"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
