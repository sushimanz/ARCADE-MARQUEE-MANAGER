#!/usr/bin/env bash
# Git Bash game-start sender.
# Usage: ./send_image_start_gitbash.sh [image_path] [COMx|/dev/ttySx]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_FILE="$SCRIPT_DIR/marquee_display.log"
TEMP_DIR="$SCRIPT_DIR/tmp"
DEFAULT_IMAGE="$SCRIPT_DIR/test.png"

SERIAL_PORT="${SERIAL_PORT:-COM3}"
BAUD_RATE="${BAUD_RATE:-1000000}"
WIDTH=256
HEIGHT=64
EXPECTED_SIZE=$((WIDTH * HEIGHT * 3))
SYNC_BYTE='\x42'
SYNC_SETTLE_SEC="${SYNC_SETTLE_SEC:-0.003}"
OPEN_SETTLE_SEC="${OPEN_SETTLE_SEC:-0.01}"
CHUNK_SIZE="${CHUNK_SIZE:-2048}"
CHUNK_DELAY_SEC="${CHUNK_DELAY_SEC:-0}"
SEND_RETRIES="${SEND_RETRIES:-2}"
ACK_START_TIMEOUT_SEC="${ACK_START_TIMEOUT_SEC:-1.5}"
ACK_DONE_TIMEOUT_SEC="${ACK_DONE_TIMEOUT_SEC:-6.0}"
BOOT_SETTLE_SEC="${BOOT_SETTLE_SEC:-0.2}"
BOOT_DRAIN_SEC="${BOOT_DRAIN_SEC:-0.4}"

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

    return 1
}

prepare_serial_session() {
    local serial_device="$1"
    local junk=""
    local drain_deadline
    local speed_out=""

    speed_out="$(stty -F "$serial_device" speed 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ -n "$speed_out" ]]; then
        log "INFO: tty speed readback on $serial_device: $speed_out (expected $BAUD_RATE)"
    else
        log "WARN: Could not read tty speed on $serial_device"
    fi

    exec 3<>"$serial_device"
    sleep "$BOOT_SETTLE_SEC"

    drain_deadline=$(( $(date +%s) + ${BOOT_DRAIN_SEC%%.*} + 1 ))
    while [[ $(date +%s) -lt $drain_deadline ]]; do
        if ! IFS= read -r -u 3 -N 1 -t 0.05 junk; then
            continue
        fi
    done
}

send_payload() {
    local temp_pixels="$1"
    local total_bytes="$2"
    local quiet_fail_log="${3:-0}"
    local offset=0
    local chunk_idx=0

    sleep "$OPEN_SETTLE_SEC"
    printf '%b' "$SYNC_BYTE" >&3
    sleep "$SYNC_SETTLE_SEC"

    local ack_byte=""
    if ! IFS= read -r -u 3 -N 1 -t "$ACK_START_TIMEOUT_SEC" ack_byte; then
        if [[ "$quiet_fail_log" != "1" ]]; then
            log "WARN: No START ACK from ESP"
        fi
        return 1
    fi
    if [[ "$ack_byte" != "S" ]]; then
        if [[ "$quiet_fail_log" != "1" ]]; then
            log "WARN: Unexpected START ACK byte: $ack_byte"
        fi
        return 1
    fi

    while [[ "$offset" -lt "$total_bytes" ]]; do
        dd if="$temp_pixels" bs="$CHUNK_SIZE" skip="$chunk_idx" count=1 status=none >&3
        offset=$((offset + CHUNK_SIZE))
        chunk_idx=$((chunk_idx + 1))
        if [[ "$CHUNK_DELAY_SEC" != "0" ]]; then
            sleep "$CHUNK_DELAY_SEC"
        fi
    done

    local done_deadline
    done_deadline=$(( $(date +%s) + ${ACK_DONE_TIMEOUT_SEC%%.*} + 1 ))
    while true; do
        ack_byte=""
        if IFS= read -r -u 3 -N 1 -t 0.5 ack_byte; then
            if [[ "$ack_byte" == "D" ]]; then
                break
            fi
            if [[ "$ack_byte" == "F" ]]; then
                if [[ "$quiet_fail_log" != "1" ]]; then
                    log "WARN: ESP reported transfer failure (ACK=F)"
                fi
                return 1
            fi
            # Ignore extra START ACKs or noise while waiting for DONE.
            continue
        fi

        if [[ $(date +%s) -ge $done_deadline ]]; then
            if [[ "$quiet_fail_log" != "1" ]]; then
                log "WARN: No DONE ACK from ESP within timeout"
            fi
            return 1
        fi
    done
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

    if ! prepare_serial_session "$serial_device"; then
        echo "ERROR: Failed to open serial device session: $serial_device"
        exit 1
    fi

    local attempt=1
    local sent_ok=0

    while [[ "$attempt" -le "$SEND_RETRIES" ]]; do
        if send_payload "$temp_pixels" "$actual_size" 0; then
            sent_ok=1
            break
        fi
        log "WARN: Send attempt $attempt/$SEND_RETRIES failed"
        sleep 0.05
        attempt=$((attempt + 1))
    done

    if [[ "$sent_ok" -ne 1 ]]; then
        echo "ERROR: Failed to send image payload after $SEND_RETRIES attempts"
        exit 1
    fi

    log "SUCCESS: Sent image $image_path to $serial_device"
    echo "SUCCESS: Sent image $image_path to $serial_device"
}

main "$@"
