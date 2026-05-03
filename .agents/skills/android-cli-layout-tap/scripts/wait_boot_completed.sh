#!/usr/bin/env bash
# Block until `sys.boot_completed` is 1 (polls every 2s).
#
# Usage: wait_boot_completed.sh <device-serial>
#    or: ANDROID_SERIAL=... wait_boot_completed.sh
#
# Example:
#   bash wait_boot_completed.sh emulator-5554

set -euo pipefail
DEVICE="${1:-${ANDROID_SERIAL:-}}"
if [[ -z "$DEVICE" ]]; then
  echo "Usage: $0 <device-serial>" >&2
  exit 1
fi

echo "wait_boot_completed: waiting on $DEVICE..." >&2
until [[ "$(adb -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
  sleep 2
done
echo "wait_boot_completed: boot completed on $DEVICE" >&2
