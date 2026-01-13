#!/bin/bash

# GPU Screen Recorder Wrapper for Wayland
# Fixed for Dell Latitude 3480 (Intel GPU) on Arch Linux
# Records fullscreen or window/area with system audio

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
FPS=60
QUALITY="very_high"
CODEC="auto"  # Will be auto-detected
CONTAINER="mp4"
OUTPUT_DIR="$HOME/Videos"
AUDIO_SOURCE=""
INCLUDE_MIC=false
CPU_FALLBACK=false

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to detect Wayland compositor
detect_compositor() {
    if [ -n "$WAYLAND_DISPLAY" ]; then
        local compositor="unknown"
        if [ -n "$XDG_CURRENT_DESKTOP" ]; then
            compositor="$XDG_CURRENT_DESKTOP"
        fi
        print_info "Detected Wayland compositor: $compositor"
    else
        print_error "Not running on Wayland!"
        print_info "This script requires Wayland. Current session: ${XDG_SESSION_TYPE:-unknown}"
        exit 1
    fi
}

# Function to check and detect supported codecs
detect_supported_codecs() {
    print_info "Checking GPU hardware encoding support..."
    
    if ! command -v vainfo &> /dev/null; then
        print_warning "vainfo not installed - cannot detect hardware encoding support"
        print_info "Install with: sudo pacman -S libva-utils"
        CPU_FALLBACK=true
        CODEC="h264"
        return
    fi
    
    # Run vainfo and check for encoding support
    local vainfo_output=$(vainfo 2>&1)
    
    if echo "$vainfo_output" | grep -q "error"; then
        print_warning "VAAPI initialization failed - hardware encoding not available"
        print_info "Falling back to CPU encoding"
        CPU_FALLBACK=true
        CODEC="h264"
        return
    fi
    
    # Check for supported encoding profiles
    local encoding_profiles=$(echo "$vainfo_output" | grep "VAEntrypointEncSlice")
    
    if [ -z "$encoding_profiles" ]; then
        print_warning "No hardware encoding profiles found"
        print_info "Your Intel GPU drivers may not support hardware encoding"
        print_info "Falling back to CPU encoding"
        CPU_FALLBACK=true
        CODEC="h264"
        return
    fi
    
    print_success "Hardware encoding is supported!"
    echo "$encoding_profiles" | head -5
    
    # Auto-detect best codec
    if echo "$encoding_profiles" | grep -qi "VAProfileH264"; then
        CODEC="h264"
        print_info "Selected codec: H.264 (hardware accelerated)"
    elif echo "$encoding_profiles" | grep -qi "VAProfileHEVC\|VAProfileH265"; then
        CODEC="hevc"
        print_info "Selected codec: HEVC (hardware accelerated)"
    elif echo "$encoding_profiles" | grep -qi "VAProfileAV1"; then
        CODEC="av1"
        print_info "Selected codec: AV1 (hardware accelerated)"
    elif echo "$encoding_profiles" | grep -qi "VAProfileVP9"; then
        CODEC="vp9"
        print_info "Selected codec: VP9 (hardware accelerated)"
    else
        print_warning "No common codec found, using CPU encoding"
        CPU_FALLBACK=true
        CODEC="h264"
    fi
}

# Function to detect audio system and set appropriate source
detect_audio() {
    if command -v pactl &> /dev/null; then
        # Check if PipeWire or PulseAudio
        if pactl info | grep -q "Server Name.*PipeWire"; then
            print_info "Detected PipeWire audio system"
            # For PipeWire, use default audio output
            AUDIO_SOURCE="default_output"
        else
            print_info "Detected PulseAudio system"
            # For PulseAudio, try to get the default sink
            local default_sink=$(pactl get-default-sink 2>/dev/null || echo "default_output")
            AUDIO_SOURCE="$default_sink.monitor"
        fi
    else
        print_warning "pactl not found, using default audio source"
        AUDIO_SOURCE="default_output"
    fi
    
    if [ "$INCLUDE_MIC" = true ]; then
        AUDIO_SOURCE="${AUDIO_SOURCE}|default_input"
        print_info "Microphone will be included in recording"
    fi
    
    print_info "Audio source: $AUDIO_SOURCE"
}

# Function to check GPU compatibility
check_gpu() {
    if command -v lspci &> /dev/null; then
        local gpu_info=$(lspci | grep -i 'vga\|3d\|display')
        print_info "GPU detected: $gpu_info"
        
        if echo "$gpu_info" | grep -qi "intel"; then
            print_info "Intel GPU detected"
            
            # Check for Intel media driver
            if ! pacman -Qi intel-media-driver &>/dev/null; then
                print_warning "intel-media-driver is not installed!"
                print_info "Install with: sudo pacman -S intel-media-driver"
                print_info "Also install: sudo pacman -S libva-intel-driver libva-utils"
            fi
        elif echo "$gpu_info" | grep -qi "nvidia"; then
            print_info "NVIDIA GPU detected - using NVENC acceleration"
        elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
            print_info "AMD GPU detected - using VAAPI acceleration"
        else
            print_warning "Unknown GPU - recording may not work optimally"
        fi
    fi
}

# Function to check if gpu-screen-recorder is installed
check_dependencies() {
    local missing_deps=()
    
    if ! command -v gpu-screen-recorder &> /dev/null; then
        missing_deps+=("gpu-screen-recorder")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo ""
        print_info "Installation commands:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                gpu-screen-recorder)
                    echo "  yay -S gpu-screen-recorder-git"
                    echo "  OR"
                    echo "  paru -S gpu-screen-recorder-git"
                    ;;
            esac
        done
        exit 1
    fi
}

# Function to check portal support for area recording
check_portal() {
    # Check for xdg-desktop-portal
    if ! systemctl --user is-active --quiet xdg-desktop-portal.service 2>/dev/null; then
        print_warning "xdg-desktop-portal service not running"
        print_info "You may need to install: xdg-desktop-portal-gtk or xdg-desktop-portal-gnome"
        print_info "Start with: systemctl --user start xdg-desktop-portal.service"
    fi
    
    return 0
}

# Function to generate output filename
generate_filename() {
    local prefix=$1
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    echo "${OUTPUT_DIR}/${prefix}_${timestamp}.${CONTAINER}"
}

# Function to build gpu-screen-recorder command
build_record_command() {
    local window_type=$1
    local output_file=$2
    
    local cmd="gpu-screen-recorder -w \"$window_type\" -f $FPS -a \"$AUDIO_SOURCE\" -q $QUALITY -k $CODEC"
    
    if [ "$CPU_FALLBACK" = true ]; then
        cmd="$cmd -fallback-cpu-encoding yes"
        print_warning "Using CPU encoding (slower, higher CPU usage)"
    fi
    
    cmd="$cmd -o \"$output_file\""
    
    echo "$cmd"
}

# Function to record fullscreen
record_fullscreen() {
    detect_audio
    detect_supported_codecs
    
    local output_file=$(generate_filename "fullscreen")
    
    print_info "Starting fullscreen recording..."
    print_info "Codec: $CODEC $([ "$CPU_FALLBACK" = true ] && echo "(CPU)" || echo "(GPU)")"
    print_info "Output: $output_file"
    print_info "Press Ctrl+C to stop recording"
    echo ""
    
    # Add trap to handle Ctrl+C gracefully
    trap 'echo ""; print_success "Recording stopped"; exit 0' INT
    
    local cmd_args=(-w screen -f "$FPS" -a "$AUDIO_SOURCE" -q "$QUALITY" -k "$CODEC")
    
    if [ "$CPU_FALLBACK" = true ]; then
        cmd_args+=(-fallback-cpu-encoding yes)
    fi
    
    cmd_args+=(-o "$output_file")
    
    gpu-screen-recorder "${cmd_args[@]}" || {
        print_error "Recording failed!"
        echo ""
        print_info "Troubleshooting:"
        echo "  1. Run: vainfo"
        echo "  2. Check if intel-media-driver is installed: pacman -Qi intel-media-driver"
        echo "  3. Try with CPU encoding: Set CPU_FALLBACK=true in settings"
        echo "  4. Check available codecs with option 6 (Test Audio)"
        exit 1
    }
    
    print_success "Recording saved to: $output_file"
}

# Function to record focused window
record_window() {
    detect_audio
    detect_supported_codecs
    
    print_info "Recording options:"
    echo "  1) Currently focused window"
    echo "  2) Select window by title"
    echo ""
    read -p "Enter your choice [1-2]: " window_choice
    
    local window_target=""
    
    case $window_choice in
        1)
            window_target="focused"
            print_info "Recording will start in 3 seconds..."
            print_info "Make sure the window you want to record is focused!"
            sleep 3
            ;;
        2)
            print_info "Enter the window title (or part of it):"
            read -p "Window title: " window_title
            if [ -z "$window_title" ]; then
                print_error "No window title provided"
                exit 1
            fi
            window_target="$window_title"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    local output_file=$(generate_filename "window")
    
    print_info "Starting window recording..."
    print_info "Codec: $CODEC $([ "$CPU_FALLBACK" = true ] && echo "(CPU)" || echo "(GPU)")"
    print_info "Output: $output_file"
    print_info "Press Ctrl+C to stop recording"
    echo ""
    
    trap 'echo ""; print_success "Recording stopped"; exit 0' INT
    
    local cmd_args=(-w "$window_target" -f "$FPS" -a "$AUDIO_SOURCE" -q "$QUALITY" -k "$CODEC")
    
    if [ "$CPU_FALLBACK" = true ]; then
        cmd_args+=(-fallback-cpu-encoding yes)
    fi
    
    cmd_args+=(-o "$output_file")
    
    gpu-screen-recorder "${cmd_args[@]}" || {
        print_error "Recording failed!"
        print_info "Make sure the window is focused and visible"
        exit 1
    }
    
    print_success "Recording saved to: $output_file"
}

# Function to record area/region
record_area() {
    detect_audio
    detect_supported_codecs
    
    check_portal
    
    print_info "Starting portal-based screen recording..."
    print_info "A system dialog should appear to select the area/window"
    
    local output_file=$(generate_filename "region")
    
    print_info "Codec: $CODEC $([ "$CPU_FALLBACK" = true ] && echo "(CPU)" || echo "(GPU)")"
    print_info "Output: $output_file"
    print_info "Press Ctrl+C to stop recording"
    echo ""
    
    trap 'echo ""; print_success "Recording stopped"; exit 0' INT
    
    local cmd_args=(-w portal -f "$FPS" -a "$AUDIO_SOURCE" -q "$QUALITY" -k "$CODEC")
    
    if [ "$CPU_FALLBACK" = true ]; then
        cmd_args+=(-fallback-cpu-encoding yes)
    fi
    
    cmd_args+=(-o "$output_file")
    
    gpu-screen-recorder "${cmd_args[@]}" || {
        print_error "Recording failed!"
        print_info "Make sure xdg-desktop-portal is installed and running"
        print_info "Install: sudo pacman -S xdg-desktop-portal-gtk"
        exit 1
    }
    
    print_success "Recording saved to: $output_file"
}

# Function to show menu
show_menu() {
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║   GPU Screen Recorder (Wayland)            ║"
    echo "║   Dell Latitude 3480 - Intel GPU           ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    if [ "$INCLUDE_MIC" = true ]; then
        echo "🎤 Microphone: ENABLED"
    else
        echo "🔇 Microphone: DISABLED (system audio only)"
    fi
    if [ "$CPU_FALLBACK" = true ]; then
        echo "⚙️  Encoding: CPU (fallback mode)"
    else
        echo "⚡ Encoding: GPU Hardware Acceleration"
    fi
    echo ""
    echo "Select recording mode:"
    echo "  1) Fullscreen"
    echo "  2) Window"
    echo "  3) Area/Region (Portal)"
    echo "  4) Settings"
    echo "  5) Toggle Microphone"
    echo "  6) Run Diagnostics"
    echo "  7) Toggle CPU Fallback"
    echo "  8) Exit"
    echo ""
    read -p "Enter your choice [1-8]: " choice
}

# Function to run diagnostics
run_diagnostics() {
    echo ""
    print_info "=== GPU Screen Recorder Diagnostics ==="
    echo ""
    
    # Check session
    print_info "Session Type: ${XDG_SESSION_TYPE:-unknown}"
    print_info "Desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    print_info "Wayland Display: ${WAYLAND_DISPLAY:-not set}"
    
    # Check GPU
    echo ""
    check_gpu
    
    # Check Intel drivers
    echo ""
    print_info "Checking Intel drivers..."
    if pacman -Qi intel-media-driver &>/dev/null; then
        print_success "intel-media-driver: INSTALLED"
    else
        print_error "intel-media-driver: NOT INSTALLED"
        print_info "Install with: sudo pacman -S intel-media-driver"
    fi
    
    if pacman -Qi libva-intel-driver &>/dev/null; then
        print_success "libva-intel-driver: INSTALLED"
    else
        print_warning "libva-intel-driver: NOT INSTALLED (optional)"
        print_info "Install with: sudo pacman -S libva-intel-driver"
    fi
    
    if pacman -Qi libva-utils &>/dev/null; then
        print_success "libva-utils: INSTALLED"
    else
        print_warning "libva-utils: NOT INSTALLED"
        print_info "Install with: sudo pacman -S libva-utils"
    fi
    
    # Run vainfo
    echo ""
    if command -v vainfo &> /dev/null; then
        print_info "Running vainfo..."
        echo "----------------------------------------"
        vainfo 2>&1
        echo "----------------------------------------"
        echo ""
        print_info "Checking encoding support..."
        local encoding=$(vainfo 2>&1 | grep "VAEntrypointEncSlice")
        if [ -n "$encoding" ]; then
            print_success "Hardware encoding is supported:"
            echo "$encoding"
        else
            print_error "No hardware encoding support found!"
            print_info "This means your GPU cannot do hardware accelerated encoding"
            print_info "You must use CPU encoding (will be slower)"
        fi
    else
        print_error "vainfo not found - install libva-utils"
    fi
    
    # Check audio
    echo ""
    print_info "Audio system:"
    detect_audio
    
    # Recommendations
    echo ""
    print_info "=== Recommendations ==="
    if ! pacman -Qi intel-media-driver &>/dev/null; then
        echo "  ⚠️  Install intel-media-driver: sudo pacman -S intel-media-driver libva-intel-driver libva-utils"
    fi
    
    if ! command -v vainfo &> /dev/null || ! vainfo 2>&1 | grep -q "VAEntrypointEncSlice"; then
        echo "  ⚠️  Hardware encoding not available - use CPU fallback mode (option 7)"
    else
        echo "  ✅ Hardware encoding is available!"
    fi
    
    echo ""
}

# Function to show and modify settings
show_settings() {
    while true; do
        echo ""
        echo "═══════════════════════════════════════"
        echo "Current Settings:"
        echo "═══════════════════════════════════════"
        echo "  FPS:            $FPS"
        echo "  Quality:        $QUALITY"
        echo "  Codec:          $CODEC"
        echo "  Container:      $CONTAINER"
        echo "  Output Dir:     $OUTPUT_DIR"
        echo "  Microphone:     $([ "$INCLUDE_MIC" = true ] && echo "ENABLED" || echo "DISABLED")"
        echo "  CPU Fallback:   $([ "$CPU_FALLBACK" = true ] && echo "ENABLED" || echo "DISABLED")"
        echo "═══════════════════════════════════════"
        echo ""
        echo "1) Change FPS (current: $FPS)"
        echo "2) Change Quality (current: $QUALITY)"
        echo "3) Change Codec (current: $CODEC)"
        echo "4) Change Container (current: $CONTAINER)"
        echo "5) Change Output Directory (current: $OUTPUT_DIR)"
        echo "6) Toggle CPU Fallback (current: $([ "$CPU_FALLBACK" = true ] && echo "ON" || echo "OFF"))"
        echo "7) Back to main menu"
        echo ""
        read -p "Enter your choice [1-7]: " settings_choice
        
        case $settings_choice in
            1)
                read -p "Enter FPS (e.g., 30, 60, 120, 144): " new_fps
                if [[ "$new_fps" =~ ^[0-9]+$ ]]; then
                    FPS=$new_fps
                    print_success "FPS set to $FPS"
                else
                    print_error "Invalid FPS value"
                fi
                ;;
            2)
                echo "Quality options: medium, high, very_high, ultra"
                read -p "Enter quality: " new_quality
                QUALITY=$new_quality
                print_success "Quality set to $QUALITY"
                ;;
            3)
                echo "Codec options: h264, hevc, av1, vp9, auto"
                read -p "Enter codec: " new_codec
                CODEC=$new_codec
                print_success "Codec set to $CODEC"
                ;;
            4)
                echo "Container options: mp4, mkv, webm"
                read -p "Enter container: " new_container
                CONTAINER=$new_container
                print_success "Container set to $CONTAINER"
                ;;
            5)
                read -p "Enter output directory: " new_dir
                new_dir="${new_dir/#\~/$HOME}"
                mkdir -p "$new_dir" 2>/dev/null || {
                    print_error "Cannot create directory: $new_dir"
                    continue
                }
                OUTPUT_DIR=$new_dir
                print_success "Output directory set to $OUTPUT_DIR"
                ;;
            6)
                if [ "$CPU_FALLBACK" = true ]; then
                    CPU_FALLBACK=false
                    print_info "CPU fallback disabled - will try GPU encoding"
                else
                    CPU_FALLBACK=true
                    print_warning "CPU fallback enabled - recording will use CPU (slower)"
                fi
                ;;
            7)
                break
                ;;
            *)
                print_error "Invalid choice"
                ;;
        esac
    done
}

# Main function
main() {
    # Show diagnostics on first run
    if [ "$1" = "info" ] || [ "$1" = "help" ] || [ "$1" = "h" ] || [ "$1" = "diag" ]; then
        run_diagnostics
        exit 0
    fi
    
    check_dependencies
    detect_compositor
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"
    
    # If arguments are provided, use them directly
    if [ $# -gt 0 ]; then
        case "$1" in
            fullscreen|full|f)
                record_fullscreen
                ;;
            window|win|w)
                record_window
                ;;
            area|region|a|r)
                record_area
                ;;
            *)
                print_error "Invalid argument. Use: fullscreen, window, area, or diag"
                exit 1
                ;;
        esac
        exit 0
    fi
    
    # Interactive menu mode
    while true; do
        show_menu
        
        case $choice in
            1)
                record_fullscreen
                ;;
            2)
                record_window
                ;;
            3)
                record_area
                ;;
            4)
                show_settings
                ;;
            5)
                if [ "$INCLUDE_MIC" = true ]; then
                    INCLUDE_MIC=false
                    print_info "Microphone disabled"
                else
                    INCLUDE_MIC=true
                    print_warning "Microphone enabled - your voice will be recorded"
                fi
                ;;
            6)
                run_diagnostics
                read -p "Press Enter to continue..."
                ;;
            7)
                if [ "$CPU_FALLBACK" = true ]; then
                    CPU_FALLBACK=false
                    print_info "CPU fallback disabled - will try GPU encoding"
                else
                    CPU_FALLBACK=true
                    print_warning "CPU fallback enabled - recording will use CPU"
                fi
                ;;
            8)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1-8."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
