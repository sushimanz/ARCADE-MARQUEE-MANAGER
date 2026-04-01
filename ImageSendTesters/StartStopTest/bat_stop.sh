#!/bin/bash
# Batocera game-end marquee stop signal.
# Usage: ./send_image_stop_batocera.sh

set -euo pipefail

SERIAL_PORT="${SERIAL_PORT:-/dev/ttyUSB0}"
BAUD_RATE="${BAUD_RATE:-1500000}"
EXIT_IMAGE_MODE_BYTE='\x45'
LOG_FILE="/tmp/marquee_display.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

find_device() {
    local port="$1"
    if [[ -n "$port" ]] && [[ -e "$port" ]]; then
        echo "$port"
        return 0
    fi

    local dev
    for dev in /dev/ttyUSB0 /dev/ttyACM0 /dev/ttyUSB1 /dev/ttyACM1; do
        if [[ -e "$dev" ]]; then
            echo "$dev"
            return 0
        fi
    done

    return 1
}

main() {
    local device
    device="$(find_device "$SERIAL_PORT")"
    if [[ -z "$device" ]] || [[ ! -e "$device" ]]; then
        log "ERROR: Serial device not found: $SERIAL_PORT"
        echo "ERROR: Serial device not found: $SERIAL_PORT"
        exit 1
    fi

    stty -F "$device" "$BAUD_RATE" raw -echo -echoe -echok -hupcl clocal 2>/dev/null || true

    exec 3>"$device"
    printf '%b' "$EXIT_IMAGE_MODE_BYTE" >&3
    exec 3>&-

    log "SUCCESS: Sent exit-image-mode signal to $device"
    echo "SUCCESS: Sent exit-image-mode signal to $device"
}

main "$@"
