#!/usr/bin/env bash
# Git Bash game-start sender.
# Usage: ./send_image_start_gitbash.sh [image_path] [COMx|/dev/ttySx]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_FILE="$SCRIPT_DIR/marquee_display.log"
TEMP_DIR="$SCRIPT_DIR/tmp"
DEFAULT_IMAGE="$SCRIPT_DIR/test.png"

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
}
trap cleanup EXIT INT TERM

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

resolve_serial_device() {
    local port="$1"
    if [[ "$port" =~ ^[Cc][Oo][Mm]([0-9]+)$ ]]; then
        local com_num="${BASH_REMATCH[1]}"
        echo "/dev/ttyS$((com_num - 1))"
        return 0
    fi
    echo "$port"
}

find_device() {
    local requested_port="$1"
    local resolved

    resolved="$(resolve_serial_device "$requested_port")"
    if [[ -e "$resolved" ]]; then
        echo "$resolved"
        return 0
    fi

    local dev
    for dev in /dev/ttyS2 /dev/ttyS3 /dev/ttyS1 /dev/ttyS0 /dev/ttyS4 /dev/ttyS5; do
        if [[ -e "$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done

    return 1
}

main() {
    local image_path="${1:-$DEFAULT_IMAGE}"
    local requested_port="${2:-$SERIAL_PORT}"
    local serial_device
    local temp_pixels="$TEMP_DIR/marquee_$$.bin"

    if [[ ! -f "$image_path" ]]; then
        echo "ERROR: Image not found: $image_path"
        exit 1
    fi

    serial_device="$(find_device "$requested_port")"
    if [[ -z "$serial_device" ]] || [[ ! -e "$serial_device" ]]; then
        echo "ERROR: Serial device not found: $requested_port"
        exit 1
    fi

    stty -F "$serial_device" "$BAUD_RATE" raw -echo -echoe -echok -hupcl clocal 2>/dev/null || true

    ffmpeg -i "$image_path" \
        -vf "scale=${WIDTH}:${HEIGHT},pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" \
        -pix_fmt rgb24 \
        -f rawvideo \
        -y "$temp_pixels" >/dev/null 2>&1 || {
        echo "ERROR: ffmpeg failed"
        exit 1
    }

    local actual_size
    actual_size=$(wc -c < "$temp_pixels")
    if [[ "$actual_size" -ne "$EXPECTED_SIZE" ]]; then
        echo "ERROR: Invalid pixel buffer size: $actual_size"
        exit 1
    fi

    exec 3>"$serial_device"
    printf '%b' "$SYNC_BYTE" >&3
    sleep "$SYNC_SETTLE_SEC"
    cat "$temp_pixels" >&3
    exec 3>&-

    log "SUCCESS: Sent image $image_path to $serial_device"
    echo "SUCCESS: Sent image $image_path to $serial_device"
}

main "$@"
