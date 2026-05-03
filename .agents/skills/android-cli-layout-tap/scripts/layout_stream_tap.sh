#!/usr/bin/env bash
# Stream `android layout -p` for a device and pass filters to layout_find_tap.mjs (Node).
# Usage: layout_stream_tap.sh <device-serial> [--desc-contains Explore] [--adb emulator-5554] ...

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:?Usage: $0 <device-serial> [layout_find_tap.mjs options...]}"
shift
exec android layout --device="$DEVICE" -p | node "$ROOT/layout_find_tap.mjs" "$@"
