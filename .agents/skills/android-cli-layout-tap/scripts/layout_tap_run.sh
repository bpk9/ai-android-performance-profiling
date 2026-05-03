#!/usr/bin/env bash
# Fresh layout → resolve tap coordinates → run `adb shell input tap` (does not only print).
# Do not combine with --json, --list, --adb, or --list-all-labels (stdout must be "x y").
#
# Usage: layout_tap_run.sh <device-serial> [layout_find_tap.mjs options...]
#
# Example:
#   bash layout_tap_run.sh emulator-5554 --find Explore
#   bash layout_tap_run.sh emulator-5554 --desc-contains Settings

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:?Usage: $0 <device-serial> [layout_find_tap.mjs options...]}"
shift

out="$(android layout --device="$DEVICE" -p | node "$ROOT/layout_find_tap.mjs" "$@")" || exit $?

if ! [[ "$out" =~ ^[0-9]+[[:space:]]+[0-9]+$ ]]; then
  echo "layout_tap_run: expected coordinate line 'x y' on stdout; omit --json/--list/--adb/--list-all-labels" >&2
  echo "Got: ${out:0:120}" >&2
  exit 2
fi

read -r X Y <<<"$out"
exec adb -s "$DEVICE" shell input tap "$X" "$Y"
