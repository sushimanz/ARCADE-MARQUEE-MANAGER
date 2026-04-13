#!/bin/bash
# Batocera game-end marquee stop signal.
# Usage: ./bat_stop.sh

set -euo pipefail

SERIAL_PORT="${SERIAL_PORT:-/dev/ttyUSB0}"
BAUD_RATE="${BAUD_RATE:-1000000}"
EXIT_IMAGE_MODE_BYTE='\x45'
LOG_FILE="/tmp/marquee_display.log"
LOCK_DIR="/tmp/marquee_serial.lockdir"
LOCK_PID_FILE="$LOCK_DIR/pid"
LOCK_HELD=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

cleanup() {
    if [[ "$LOCK_HELD" -eq 1 ]]; then
        rm -f "$LOCK_PID_FILE" 2>/dev/null || true
        rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

acquire_lock() {
    local timeout_s="${1:-2}"
    local deadline=$(( $(date +%s) + timeout_s ))

    while true; do
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            echo "$$" > "$LOCK_PID_FILE" 2>/dev/null || true
            LOCK_HELD=1
            return 0
        fi

        local existing_pid
        existing_pid="$(cat "$LOCK_PID_FILE" 2>/dev/null || true)"
        if [[ -n "$existing_pid" ]] && ! kill -0 "$existing_pid" 2>/dev/null; then
            rm -f "$LOCK_PID_FILE" 2>/dev/null || true
            rmdir "$LOCK_DIR" 2>/dev/null || true
            continue
        fi

        if [[ $(date +%s) -ge $deadline ]]; then
            log "WARN: Timed out waiting for serial lock"
            return 1
        fi

        sleep 0.05
    done
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
    if ! acquire_lock 2; then
        echo "ERROR: serial lock busy"
        exit 1
    fi

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
