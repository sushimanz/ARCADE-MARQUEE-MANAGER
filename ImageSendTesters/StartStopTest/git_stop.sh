#!/usr/bin/env bash
# Git Bash game-end stop signal.
# Usage: ./send_image_stop_gitbash.sh [COMx|/dev/ttySx]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_FILE="$SCRIPT_DIR/marquee_display.log"

SERIAL_PORT="${SERIAL_PORT:-COM3}"
BAUD_RATE="${BAUD_RATE:-1000000}"
EXIT_IMAGE_MODE_BYTE='\x45'

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
    local requested_port="${1:-$SERIAL_PORT}"
    local serial_device

    serial_device="$(find_device "$requested_port")"
    if [[ -z "$serial_device" ]] || [[ ! -e "$serial_device" ]]; then
        echo "ERROR: Serial device not found: $requested_port"
        exit 1
    fi

    stty -F "$serial_device" "$BAUD_RATE" raw -echo -echoe -echok -hupcl clocal 2>/dev/null || true

    exec 3>"$serial_device"
    printf '%b' "$EXIT_IMAGE_MODE_BYTE" >&3
    exec 3>&-

    log "SUCCESS: Sent exit-image-mode signal to $serial_device"
    echo "SUCCESS: Sent exit-image-mode signal to $serial_device"
}

main "$@"
