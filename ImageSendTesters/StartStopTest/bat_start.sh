#!/bin/bash
# Batocera game-start marquee sender.
# Usage: ./send_image_start_batocera.sh <rom_path>

set -euo pipefail

SERIAL_PORT="${SERIAL_PORT:-/dev/ttyUSB0}"
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
BOOT_SETTLE_SEC="${BOOT_SETTLE_SEC:-0.2}"
BOOT_DRAIN_SEC="${BOOT_DRAIN_SEC:-0.4}"
ACK_START_TIMEOUT_SEC="${ACK_START_TIMEOUT_SEC:-1.5}"
ACK_DONE_TIMEOUT_SEC="${ACK_DONE_TIMEOUT_SEC:-6.0}"
START_ACK_REQUIRED="${START_ACK_REQUIRED:-0}"
DONE_ACK_REQUIRED="${DONE_ACK_REQUIRED:-0}"
ENFORCE_BAUD_MATCH="${ENFORCE_BAUD_MATCH:-1}"
TEMP_DIR="/tmp"
LOG_FILE="/tmp/marquee_display.log"
LOCK_DIR="/tmp/marquee_serial.lockdir"
LOCK_PID_FILE="$LOCK_DIR/pid"
LOCK_HELD=0

MARQUEE_DIR="/userdata/roms"
DOWNLOADED_IMAGES="/userdata/system/configs/emulationstation/downloaded_media"
DEFAULT_MARQUEE="/userdata/system/configs/marquee_default.png"

cleanup() {
    exec 3>&- 2>/dev/null || true
    if [[ "$LOCK_HELD" -eq 1 ]]; then
        rm -f "$LOCK_PID_FILE" 2>/dev/null || true
        rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
    rm -f "$TEMP_DIR"/marquee_*.bin 2>/dev/null
}
trap cleanup EXIT INT TERM

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_ffmpeg() {
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log "ERROR: FFmpeg not found"
        return 1
    fi
    return 0
}

acquire_lock() {
    local timeout_s="${1:-3}"
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

extract_system() {
    local rom_path="$1"
    echo "$rom_path" | sed 's|^.*/roms/||' | cut -d'/' -f1
}

find_marquee_image() {
    local system="$1"
    local rom_file="$2"
    local rom_name="${rom_file%.*}"
    while [[ "$rom_name" == *"\\ "* ]]; do rom_name="${rom_name//\\ / }"; done
    while [[ "$rom_name" == *"\\("* ]]; do rom_name="${rom_name//\\(/(}"; done
    while [[ "$rom_name" == *"\\)"* ]]; do rom_name="${rom_name//\\)/)}"; done
    while [[ "$rom_name" == *"\\["* ]]; do rom_name="${rom_name//\\[/[}"; done
    while [[ "$rom_name" == *"\\]"* ]]; do rom_name="${rom_name//\\]/]}"; done
    while [[ "$rom_name" == *"\\'"* ]]; do rom_name="${rom_name//\\\'/\'}"; done

    local ext
    local img

    # if [[ -n "$system" ]] && [[ -n "$rom_name" ]]; then
    #     for ext in png jpg jpeg gif; do
    #         img="$MARQUEE_DIR/$system/media/screenmarqueesmall/${rom_name}.$ext"
    #         if [[ -f "$img" ]]; then
    #             echo "$img"
    #             return 0
    #         fi
    #     done
    # fi
    if [[ -n "$system" ]] && [[ -n "$rom_name" ]]; then
        for ext in png jpg jpeg gif; do
            img="$MARQUEE_DIR/$system/media/images/${rom_name}.$ext"
            if [[ -f "$img" ]]; then
                echo "$img"
                return 0
            fi
        done
    fi

    if [[ -n "$system" ]] && [[ -n "$rom_name" ]]; then
        for ext in png jpg jpeg; do
            img="$DOWNLOADED_IMAGES/$system/screenmarqueesmall/${rom_name}.$ext"
            if [[ -f "$img" ]]; then
                echo "$img"
                return 0
            fi

            img="$DOWNLOADED_IMAGES/$system/images/${rom_name}.$ext"
            if [[ -f "$img" ]]; then
                echo "$img"
                return 0
            fi
        done
    fi

    if [[ -n "$system" ]]; then
        for ext in png jpg jpeg; do
            img="$MARQUEE_DIR/$system/media/screenmarqueesmall/default.$ext"
            if [[ -f "$img" ]]; then
                echo "$img"
                return 0
            fi
        done
    fi

    if [[ -f "$DEFAULT_MARQUEE" ]]; then
        echo "$DEFAULT_MARQUEE"
        return 0
    fi

    return 1
}

prepare_serial_session() {
    local serial_device="$1"
    local junk=""
    local drain_deadline
    local speed_out=""

    if ! stty -F "$serial_device" "$BAUD_RATE" raw -echo -echoe -echok -hupcl clocal 2>/dev/null; then
        log "ERROR: Failed to configure tty speed $BAUD_RATE on $serial_device"
        return 1
    fi

    speed_out="$(stty -F "$serial_device" speed 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ -n "$speed_out" ]]; then
        log "INFO: tty speed readback on $serial_device: $speed_out (expected $BAUD_RATE)"
        if [[ "$ENFORCE_BAUD_MATCH" == "1" ]] && [[ "$speed_out" != "$BAUD_RATE" ]]; then
            log "ERROR: tty speed mismatch on $serial_device (got $speed_out, expected $BAUD_RATE)"
            return 1
        fi
    else
        log "WARN: Could not read tty speed on $serial_device"
        if [[ "$ENFORCE_BAUD_MATCH" == "1" ]]; then
            log "ERROR: Could not verify tty speed while ENFORCE_BAUD_MATCH=1"
            return 1
        fi
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
    local ack_byte=""
    local got_start_ack=0
    local done_deadline

    sleep "$OPEN_SETTLE_SEC"
    printf '%b' "$SYNC_BYTE" >&3
    sleep "$SYNC_SETTLE_SEC"

    if ! IFS= read -r -u 3 -N 1 -t "$ACK_START_TIMEOUT_SEC" ack_byte; then
        if [[ "$quiet_fail_log" != "1" ]]; then
            log "WARN: No START ACK from ESP"
        fi
        if [[ "$START_ACK_REQUIRED" == "1" ]]; then
            return 1
        fi
    elif [[ "$ack_byte" != "S" ]]; then
        if [[ "$quiet_fail_log" != "1" ]]; then
            log "WARN: Unexpected START ACK byte: $ack_byte"
        fi
        if [[ "$START_ACK_REQUIRED" == "1" ]]; then
            return 1
        fi
    else
        got_start_ack=1
    fi

    while [[ "$offset" -lt "$total_bytes" ]]; do
        dd if="$temp_pixels" bs="$CHUNK_SIZE" skip="$chunk_idx" count=1 status=none >&3
        offset=$((offset + CHUNK_SIZE))
        chunk_idx=$((chunk_idx + 1))
        if [[ "$CHUNK_DELAY_SEC" != "0" ]]; then
            sleep "$CHUNK_DELAY_SEC"
        fi
    done

    if [[ "$got_start_ack" == "1" || "$DONE_ACK_REQUIRED" == "1" ]]; then
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
                # Ignore repeated START ACKs or serial noise while waiting for DONE.
                continue
            fi

            if [[ $(date +%s) -ge $done_deadline ]]; then
                if [[ "$quiet_fail_log" != "1" ]]; then
                    log "WARN: No DONE ACK from ESP within timeout"
                fi
                if [[ "$DONE_ACK_REQUIRED" == "1" ]]; then
                    return 1
                fi
                break
            fi
        done
    fi

    if [[ "$got_start_ack" != "1" && "$quiet_fail_log" != "1" ]]; then
        log "WARN: Transfer sent without START ACK confirmation"
    fi
}

send_image() {
    local img_path="$1"
    local serial_port="$2"
    local temp_pixels="$TEMP_DIR/marquee_$$.bin"
    local device

    if [[ ! -f "$img_path" ]]; then
        log "ERROR: Image not found: $img_path"
        return 1
    fi

    device="$(find_device "$serial_port")"
    if [[ -z "$device" ]] || [[ ! -e "$device" ]]; then
        log "ERROR: Serial device not found: $serial_port"
        return 1
    fi

    ffmpeg -i "$img_path" \
        -vf "scale=${WIDTH}:${HEIGHT},pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" \
        -pix_fmt rgb24 \
        -f rawvideo \
        -y "$temp_pixels" >/dev/null 2>&1 || return 1

    local actual_size
    actual_size=$(wc -c < "$temp_pixels")
    if [[ "$actual_size" -ne "$EXPECTED_SIZE" ]]; then
        log "ERROR: Invalid image data size: $actual_size"
        return 1
    fi

    if ! prepare_serial_session "$device"; then
        log "ERROR: Failed to open serial device session: $device"
        return 1
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
        log "ERROR: Failed to send image payload after $SEND_RETRIES attempts"
        return 1
    fi

    log "SUCCESS: Sent image $img_path to $device"
    echo "SUCCESS: Sent image $img_path to $device"
}

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <rom_path>"
        exit 1
    fi

    if ! check_ffmpeg; then
        echo "ERROR: ffmpeg not found"
        exit 1
    fi

    if ! acquire_lock 3; then
        echo "ERROR: serial lock busy"
        exit 1
    fi

    local rom_path="$1"
    # while [[ "$rom_path" == *"\\ "* ]]; do rom_path="${rom_path//\\ / }"; done
    # while [[ "$rom_path" == *"\\("* ]]; do rom_path="${rom_path//\\(/(}"; done
    # while [[ "$rom_path" == *"\\)"* ]]; do rom_path="${rom_path//\\)/)}"; done
    # while [[ "$rom_path" == *"\\["* ]]; do rom_path="${rom_path//\\[/[}"; done
    # while [[ "$rom_path" == *"\\]"* ]]; do rom_path="${rom_path//\\]/]}"; done
    # while [[ "$rom_path" == *"\\'"* ]]; do rom_path="${rom_path//\\\'/\'}"; done
    local system rom_file image_path
    system="$(extract_system "$rom_path")"
    rom_file="$(basename "$rom_path")"

    image_path="$(find_marquee_image "$system" "$rom_file" || true)"
    if [[ -z "$image_path" ]]; then
        log "WARNING: No marquee found for $system/$rom_file"
        return 0
    fi

    send_image "$image_path" "$SERIAL_PORT"
}

main "$@"
