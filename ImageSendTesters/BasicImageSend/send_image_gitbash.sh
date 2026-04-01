#!/usr/bin/env bash
#
# Windows Git Bash image sender for ESP32 marquee.
# - Defaults to local test.png
# - Logs to this project folder
# - Supports SERIAL_PORT as COMx or /dev/ttySx
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_FILE="$SCRIPT_DIR/marquee_display.log"
TEMP_DIR="$SCRIPT_DIR/tmp"
DEFAULT_IMAGE="$SCRIPT_DIR/neobombe.png"
LOCK_FILE="$TEMP_DIR/send_image.lock"

SERIAL_PORT="${SERIAL_PORT:-COM3}"
BAUD_RATE="${BAUD_RATE:-1500000}"
WIDTH=256
HEIGHT=64
EXPECTED_SIZE=$((WIDTH * HEIGHT * 3))
SYNC_BYTE='\x42'
SYNC_SETTLE_SEC="${SYNC_SETTLE_SEC:-0.01}"

mkdir -p "$TEMP_DIR"

cleanup() {
    exec 3>&- 2>/dev/null || true
    rm -f "$TEMP_DIR"/marquee_*.bin 2>/dev/null
    rm -f "$LOCK_FILE" 2>/dev/null
}
trap cleanup EXIT INT TERM

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

acquire_lock() {
    log "[DEBUG] Attempting to acquire lock..."
    if [[ -f "$LOCK_FILE" ]]; then
        log "[DEBUG] Lock file exists, checking if process is alive..."
        local existing_pid
        existing_pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
        log "[DEBUG] Found PID in lock: $existing_pid"
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            log "ERROR: Sender already running (PID $existing_pid)"
            echo "ERROR: Sender already running (PID $existing_pid)"
            return 1
        fi
        rm -f "$LOCK_FILE" 2>/dev/null || true
    fi

    echo "$$" > "$LOCK_FILE"
    log "[DEBUG] Lock acquired successfully"
    return 0
}

check_ffmpeg() {
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log "ERROR: ffmpeg not found in PATH"
        return 1
    fi
    return 0
}

resolve_serial_device() {
    local port="$1"

    if [[ "$port" =~ ^[Cc][Oo][Mm]([0-9]+)$ ]]; then
        local com_num="${BASH_REMATCH[1]}"
        local tty_index=$((com_num - 1))
        echo "/dev/ttyS${tty_index}"
        return 0
    fi

    echo "$port"
    return 0
}

find_device() {
    local requested_port="$1"
    local resolved

    if [[ -n "$requested_port" ]]; then
        resolved="$(resolve_serial_device "$requested_port")"
        if [[ -e "$resolved" ]]; then
            echo "$resolved"
            return 0
        fi
    fi

    # Fallback scan for common Windows serial mappings inside Git Bash.
    local dev
    for dev in /dev/ttyS2 /dev/ttyS3 /dev/ttyS1 /dev/ttyS0 /dev/ttyS4 /dev/ttyS5; do
        if [[ -e "$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done

    return 1
}

configure_serial_port() {
    local requested_port="$1"
    local serial_device="$2"

    # raw + no modem control toggles helps avoid ESP resets during send.
    if stty -F "$serial_device" "$BAUD_RATE" raw -echo -echoe -echok -hupcl clocal 2>/dev/null; then
        log "[DEBUG-CFG] Configured $serial_device at $BAUD_RATE baud"
        return 0
    fi

    log "[WARN-CFG] stty configuration failed for $serial_device, continuing"
    return 0
}

send_image() {
    local img_path="$1"
    local requested_port="$2"
    local serial_device
    local temp_pixels="$TEMP_DIR/marquee_$$.bin"

    log "[DEBUG] send_image() called with img_path=$img_path, port=$requested_port"
    log "[DEBUG] Checking if image file exists: $img_path"

    if [[ ! -f "$img_path" ]]; then
        log "ERROR: Image not found: $img_path"
        echo "ERROR: Image not found: $img_path"
        return 1
    fi

    log "[DEBUG] Image file found, calling find_device()..."
    serial_device="$(find_device "$requested_port")"
    log "[DEBUG] find_device returned: $serial_device"
    if [[ $? -ne 0 ]] || [[ ! -e "$serial_device" ]]; then
        log "ERROR: Serial device not found: $requested_port"
        echo "ERROR: Serial device not found: $requested_port"
        echo "Tip: In Git Bash, COM3 maps to /dev/ttyS2"
        return 1
    fi

    log "[DEBUG] Calling configure_serial_port()..."
    if ! configure_serial_port "$requested_port" "$serial_device"; then
        log "ERROR: Failed to configure serial port $serial_device"
        echo "ERROR: Failed to configure serial port $serial_device"
        echo "Tip: Close any app using $requested_port (Arduino Serial Monitor, PlatformIO monitor, PuTTY, etc.)"
        return 1
    fi
    log "[DEBUG] Serial port configured successfully"

    log "Processing image: $img_path"
    log "[DEBUG] FFmpeg conversion starting..."
    if ! ffmpeg -i "$img_path" -vf "scale=${WIDTH}:${HEIGHT},pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" -pix_fmt rgb24 -f rawvideo -y "$temp_pixels" >/dev/null 2>&1; then
        log "ERROR: ffmpeg failed to process image"
        echo "ERROR: ffmpeg failed to process image"
        return 1
    fi

    local actual_size
    actual_size=$(wc -c < "$temp_pixels")
    if [[ "$actual_size" -ne "$EXPECTED_SIZE" ]]; then
        log "ERROR: Invalid pixel buffer size: $actual_size (expected $EXPECTED_SIZE)"
        echo "ERROR: Invalid pixel buffer size: $actual_size"
        return 1
    fi
    log "[DEBUG] FFmpeg conversion complete, opening serial device"

    exec 3>"$serial_device"
    if [[ $? -ne 0 ]]; then
        log "ERROR: Could not open serial device $serial_device"
        echo "ERROR: Could not open serial device $serial_device"
        return 1
    fi

    # Send sync byte 0x42 then stream RGB payload.
    log "[DEBUG] Sending sync byte 0x42"
    printf '%b' "$SYNC_BYTE" >&3
    log "[DEBUG] Sync byte sent, waiting ${SYNC_SETTLE_SEC}s"
    sleep "$SYNC_SETTLE_SEC"
    log "[DEBUG] Beginning direct payload stream"

    if ! cat "$temp_pixels" >&3; then
        log "ERROR: Failed while writing payload to $serial_device"
        echo "ERROR: Failed while writing payload to $serial_device"
        return 1
    fi

    log "[DEBUG] Sent $EXPECTED_SIZE payload bytes"

    log "[DEBUG] Payload stream complete, closing serial FD"
    exec 3>&-
    log "[DEBUG] Serial FD closed successfully"

    log "SUCCESS: Sent image $img_path to $serial_device"
    echo "SUCCESS: Sent image $img_path to $serial_device"
    return 0
}

main() {
    local image_path="${1:-$DEFAULT_IMAGE}"
    local port="${2:-$SERIAL_PORT}"

    log "======================================"
    log "Git Bash Marquee Send Start"
    log "Image: $image_path"
    log "Port:  $port"
    log "======================================"
    log "[DEBUG] About to check ffmpeg..."

    if ! check_ffmpeg; then
        echo "ERROR: ffmpeg not found in PATH"
        return 1
    fi

    if ! acquire_lock; then
        return 1
    fi

    log "[DEBUG] Calling send_image() with $image_path and $port"
    if ! send_image "$image_path" "$port"; then
        return 1
    fi

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        cat <<EOF
Usage:
  ./send_image_gitbash.sh [image_path] [port]

Defaults:
  image_path = $DEFAULT_IMAGE
  port       = $SERIAL_PORT

Examples:
  ./send_image_gitbash.sh
  ./send_image_gitbash.sh "$SCRIPT_DIR/test.png"
  ./send_image_gitbash.sh "$SCRIPT_DIR/test.png" COM3
  SERIAL_PORT=COM4 ./send_image_gitbash.sh

Log file:
  $LOG_FILE
EOF
        exit 0
    fi

    main "${1:-}" "${2:-}"
    exit $?
fi
