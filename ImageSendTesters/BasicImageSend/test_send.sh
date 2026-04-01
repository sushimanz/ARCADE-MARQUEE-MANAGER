#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOCK_FILE="$SCRIPT_DIR/tmp/send_image.lock"

echo "=== Clearing stale lock file if present ==="
rm -f "$LOCK_FILE" 2>/dev/null && echo "Lock cleared" || echo "No lock file to clear"

echo "=== Running send_image_gitbash.sh with debug output ==="
echo ""

# Run the sender and show output in real-time
bash "$SCRIPT_DIR/send_image_gitbash.sh" "${1:-test.png}" "${2:-COM3}"
EXIT_CODE=$?

echo ""
echo "=== Script exited with code: $EXIT_CODE ==="
exit $EXIT_CODE
