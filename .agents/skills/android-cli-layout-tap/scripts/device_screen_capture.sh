#!/usr/bin/env bash
# PNG screenshot via Android CLI; prints output path on stdout.
# Uses ANDROID_SERIAL for the active device so `android screen capture` targets the right device.
#
# Usage: device_screen_capture.sh <device-serial> [output.png]
#
# Example:
#   png="$(bash device_screen_capture.sh emulator-5554 /tmp/check.png)"

set -euo pipefail
DEVICE="${1:?Usage: $0 <device-serial> [output.png]}"
shift
safe="${DEVICE//[^a-zA-Z0-9._-]/_}"
OUT="${1:-${TMPDIR:-/tmp}/android-screen-${safe}-$$.png}"

export ANDROID_SERIAL="$DEVICE"
android screen capture -o "$OUT"
echo "$OUT"
