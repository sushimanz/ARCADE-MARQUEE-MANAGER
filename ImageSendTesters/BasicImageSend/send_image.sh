#!/bin/bash
#
# Batocera LED Matrix Marquee Display Script
# Compatible with ESP32 serial protocol (sync byte 0x42 + raw RGB data)
# Display: 256x64 (4x 64x64 HUB75 panels chained)
# Uses FFmpeg (pre-installed on Batocera) for image processing
#
# EmulationStation passes:
#   $1 = rom_path   (Full path to the ROM file, e.g., /userdata/roms/arcade/pacman.zip)
#
# System name is extracted from the ROM path automatically
#
# Usage in Batocera (add to /userdata/system/scripts/custom.sh):
#   /userdata/system/scripts/send_image.sh "$1"
#

# --- Configuration ---
SERIAL_PORT="${SERIAL_PORT:-/dev/ttyUSB0}"
BAUD_RATE="${BAUD_RATE:-1500000}"
WIDTH=256   # 4 panels × 64
HEIGHT=64   # Panel height
SYNC_BYTE='\x42'
SYNC_SETTLE_SEC="${SYNC_SETTLE_SEC:-0.01}"
TEMP_DIR="/tmp"
LOG_FILE="/tmp/marquee_display.log"

# Batocera paths
MARQUEE_DIR="/userdata/roms"
DOWNLOADED_IMAGES="/userdata/system/configs/emulationstation/downloaded_media"
DEFAULT_MARQUEE="/userdata/system/configs/marquee_default.png"

# Cleanup handler
cleanup() {
    rm -f "$TEMP_DIR"/marquee_*.bin 2>/dev/null
}
trap cleanup EXIT INT TERM

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check for FFmpeg (pre-installed on Batocera)
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        log "ERROR: FFmpeg not found"
        return 1
    fi
    return 0
}

# Auto-detect serial device
find_device() {
    local port="$1"
    
    # If specified and exists, use it
    if [[ -n "$port" ]] && [[ -e "$port" ]]; then
        echo "$port"
        return 0
    fi
    
    # Auto-detect common USB serial devices
    for dev in /dev/ttyUSB0 /dev/ttyACM0 /dev/ttyUSB1 /dev/ttyACM1; do
        if [[ -e "$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done
    
    return 1
}

# Find marquee image for a game
# Priority: system marquees folder > downloaded media > ROM folder > default
find_marquee_image() {
    local system="$1"
    local rom_file="$2"
    local rom_name="${rom_file%.*}"  # Remove extension
    
    log "Finding marquee: system=$system, rom=$rom_file"
    
    # 1. Check system's marquees folder (using ROM filename without extension)
    if [[ -n "$system" ]] && [[ -n "$rom_name" ]]; then
        for ext in png jpg jpeg gif; do
            local img="$MARQUEE_DIR/$system/media/screenmarqueesmall/${rom_name}.$ext"
            if [[ -f "$img" ]]; then
                echo "$img"
                return 0
            fi
        done
    fi
    
    # 2. Check downloaded media (EmulationStation scraped images)
    if [[ -n "$system" ]] && [[ -n "$rom_name" ]]; then
        for ext in png jpg jpeg; do
            local img="$DOWNLOADED_IMAGES/$system/screenmarqueesmall/${rom_name}.$ext"
            if [[ -f "$img" ]]; then
                echo "$img"
                return 0
            fi
            # Also check images folder
            img="$DOWNLOADED_IMAGES/$system/images/${rom_name}.$ext"
            if [[ -f "$img" ]]; then
                echo "$img"
                return 0
            fi
        done
    fi
    
    # 3. Check for system default image
    if [[ -n "$system" ]]; then
        for ext in png jpg jpeg; do
            local img="$MARQUEE_DIR/$system/media/screenmarqueesmall/default.$ext"
            if [[ -f "$img" ]]; then
                echo "$img"
                return 0
            fi
        done
    fi
    
    # 4. Use global default if exists
    if [[ -f "$DEFAULT_MARQUEE" ]]; then
        echo "$DEFAULT_MARQUEE"
        return 0
    fi
    
    # Not found
    return 1
}

# Send image to display
send_image() {
    local img_path="$1"
    local serial_port="$2"
    local temp_pixels="$TEMP_DIR/marquee_$$.bin"
    
    # Validate image file
    if [[ ! -f "$img_path" ]]; then
        log "ERROR: Image not found: $img_path"
        return 1
    fi
    
    log "Processing image: $img_path"
    
    # Find serial device
    local device=$(find_device "$serial_port")
    if [[ $? -ne 0 ]] || [[ ! -e "$device" ]]; then
        log "ERROR: Serial device not found: $serial_port"
        return 1
    fi
    
    # Configure serial port to prevent ESP32 reset
    # -hupcl: don't send hangup signal on close
    # clocal: ignore modem control lines (no DTR/RTS changes)
    # raw: raw input mode
    # -echo: don't echo input characters
    stty -F "$device" "$BAUD_RATE" raw -echo -echoe -echok -hupcl clocal 2>/dev/null
    if [[ $? -ne 0 ]]; then
        log "ERROR: Failed to configure serial port $device"
        return 1
    fi
    
    # Clear any existing data in the serial buffers
    cat "$device" > /dev/null &
    local cat_pid=$!
    sleep 0.2
    kill $cat_pid 2>/dev/null
    
    # Wait for connection to stabilize
    sleep 2
    
    # Convert image using FFmpeg: resize to target and center on black background
    # scale: resize to target dimensions
    # pad: add black borders to center the image
    # pix_fmt rgb24: output as raw RGB (3 bytes per pixel)
    # -f rawvideo: output raw video data
    ffmpeg -i "$img_path" \
        -vf "scale=${WIDTH}:${HEIGHT},pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" \
        -pix_fmt rgb24 \
        -f rawvideo \
        -y "$temp_pixels" 2>/dev/null
    
    if [[ $? -ne 0 ]]; then
        log "ERROR: Failed to process image with FFmpeg"
        rm -f "$temp_pixels"
        return 1
    fi
    
    # Verify file size (256 × 64 × 3 = 49152 bytes)
    local expected_size=$((WIDTH * HEIGHT * 3))
    local actual_size=$(stat -c%s "$temp_pixels" 2>/dev/null)
    
    if [[ "$actual_size" -ne "$expected_size" ]]; then
        log "ERROR: Invalid image data size: $actual_size (expected $expected_size)"
        rm -f "$temp_pixels"
        return 1
    fi
    
    log "Sending image pixel-by-pixel (like Python script)..."
    
    # Open device for writing
    exec 3>"$device"
    if [[ $? -ne 0 ]]; then
        log "ERROR: Failed to open serial device"
        rm -f "$temp_pixels"
        return 1
    fi
    
    # Send sync byte (0x42)
    echo -ne '\x42' >&3
    
    # Small delay after sync byte to ensure ESP32 detects it
    sleep "$SYNC_SETTLE_SEC"
    
    # Send payload directly
    if ! cat "$temp_pixels" >&3; then
        log "ERROR: Failed while writing payload to $device"
        exec 3>&-
        rm -f "$temp_pixels"
        return 1
    fi
    
    # Close device
    exec 3>&-
    
    # Give ESP32 time to finish processing
    sleep 0.5
    
    log "SUCCESS: Sent $((expected_size / 3)) pixels ($expected_size bytes) to $device"
    
    # Cleanup
    rm -f "$temp_pixels"
    return 0
}

# Extract system name from ROM path
# Example: /userdata/roms/arcade/game.zip -> arcade
extract_system() {
    local rom_path="$1"
    # Remove /userdata/roms/ prefix and get first directory
    echo "$rom_path" | sed 's|^.*/roms/||' | cut -d'/' -f1
}

# Main
main() {
    local rom_path="$1"
    
    # Extract system and ROM filename from path
    local system=$(extract_system "$rom_path")
    local rom_file=$(basename "$rom_path")
    local rom_name="${rom_file%.*}"  # Remove extension
    
    log "======================================"
    log "Batocera Marquee Display - Game Start"
    log "ROM Path: $rom_path"
    log "System:   $system"
    log "ROM File: $rom_file"
    log "ROM Name: $rom_name"
    log "======================================"
    
    # Check dependencies
    if ! check_ffmpeg; then
        exit 1
    fi
    
    # Find marquee image
    local image_path=$(find_marquee_image "$system" "$rom_file")
    if [[ $? -eq 0 ]]; then
        log "Found marquee: $image_path"
        send_image "$image_path" "$SERIAL_PORT"
    else
        log "WARNING: No marquee found for $system/$rom_file"
    fi
}

# Run main if arguments provided
if [[ $# -ge 1 ]]; then
    main "$1"
else
    cat << 'EOF'
Batocera LED Matrix Marquee Display (256x64)

This script is called by EmulationStation with:
  $1 = rom_path   (Full path to ROM, e.g., /userdata/roms/arcade/game.zip)

The system name is automatically extracted from the ROM path.

Setup:
  1. Copy to: /userdata/system/scripts/send_image.sh
  2. Make executable: chmod +x /userdata/system/scripts/send_image.sh
  3. Create: /userdata/system/scripts/custom.sh (if it doesn't exist)
  4. Make custom.sh executable: chmod +x /userdata/system/scripts/custom.sh

Create /userdata/system/scripts/custom.sh with:
  #!/bin/bash
  case "$1" in
    game-start)
      /userdata/system/scripts/send_image.sh "$2" &
      ;;
  esac

Note: EmulationStation passes event type as $1 and ROM path as $2.
The & at the end runs in background so it doesn't delay game startup.

Alternative (if ROM path is $1 directly):
  #!/bin/bash
  /userdata/system/scripts/send_image.sh "$1" &

Requirements:
  - FFmpeg (pre-installed on Batocera)
  - USB serial device (ESP32)

Image Search Priority:
  1. /userdata/roms/{system}/media/screenmarqueesmall/{rom}.png
  2. /userdata/system/configs/emulationstation/downloaded_media/{system}/screenmarqueesmall/
  3. /userdata/roms/{system}/media/screenmarqueesmall/default.png
  4. /userdata/system/configs/marquee_default.png

Environment Variables:
  SERIAL_PORT=<device>  (default: /dev/ttyUSB0)

Logs: /tmp/marquee_display.log
EOF
    exit 1
fi
