#!/bin/bash
# Batocera game-start marquee sender.
# Usage: ./send_image_start_batocera.sh <rom_path>

set -euo pipefail

SERIAL_PORT="${SERIAL_PORT:-/dev/ttyUSB0}"
BAUD_RATE="${BAUD_RATE:-1500000}"
WIDTH=256
HEIGHT=64
SYNC_BYTE='\x42'
SYNC_SETTLE_SEC="${SYNC_SETTLE_SEC:-0.01}"
TEMP_DIR="/tmp"
LOG_FILE="/tmp/marquee_display.log"

MARQUEE_DIR="/userdata/roms"
DOWNLOADED_IMAGES="/userdata/system/configs/emulationstation/downloaded_media"
DEFAULT_MARQUEE="/userdata/system/configs/marquee_default.png"

cleanup() {
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

    stty -F "$device" "$BAUD_RATE" raw -echo -echoe -echok -hupcl clocal 2>/dev/null || true

    ffmpeg -i "$img_path" \
        -vf "scale=${WIDTH}:${HEIGHT},pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" \
        -pix_fmt rgb24 \
        -f rawvideo \
        -y "$temp_pixels" >/dev/null 2>&1 || return 1

    local expected_size=$((WIDTH * HEIGHT * 3))
    local actual_size
    actual_size=$(stat -c%s "$temp_pixels" 2>/dev/null || echo 0)
    if [[ "$actual_size" -ne "$expected_size" ]]; then
        log "ERROR: Invalid image data size: $actual_size"
        return 1
    fi

    exec 3>"$device"
    printf '%b' "$SYNC_BYTE" >&3
    sleep "$SYNC_SETTLE_SEC"
    cat "$temp_pixels" >&3
    exec 3>&-

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

    local rom_path="$1"
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
