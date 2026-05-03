#!/usr/bin/env bash
# Stream layout and list every node with a parseable center (--list-all-labels).
#
# Usage: layout_labels.sh <device-serial> [extra layout_find_tap.mjs args...]
#
# Example:
#   bash layout_labels.sh emulator-5554
#   bash layout_labels.sh emulator-5554 --label-width 100

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:?Usage: $0 <device-serial> [layout_find_tap.mjs options...]}"
shift
exec android layout --device="$DEVICE" -p | node "$ROOT/layout_find_tap.mjs" --list-all-labels "$@"
