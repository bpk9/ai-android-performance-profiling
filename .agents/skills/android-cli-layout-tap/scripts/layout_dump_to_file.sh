#!/usr/bin/env bash
# Write `android layout -p` JSON to a file; print only the path on stdout (keeps huge dumps out of the terminal).
#
# Usage: layout_dump_to_file.sh <device-serial> [output.json]
#
# Example:
#   path="$(bash layout_dump_to_file.sh emulator-5554)"
#   node layout_find_tap.mjs -f "$path" --find Settings --json

set -euo pipefail
DEVICE="${1:?Usage: $0 <device-serial> [output.json]}"
shift
safe="${DEVICE//[^a-zA-Z0-9._-]/_}"
OUT="${1:-${TMPDIR:-/tmp}/android-layout-${safe}-$$.json}"

android layout --device="$DEVICE" -p >"$OUT"
echo "$OUT"
