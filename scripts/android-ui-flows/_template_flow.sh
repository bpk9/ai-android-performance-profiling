#!/usr/bin/env bash
# Template: copy to a new name (e.g. open-settings-flow.sh) and fill in the TODOs.
# See: .agents/skills/android-cli-layout-tap/SKILLS.md → "Agent UI automation flow (record → replay)"
#
# shellcheck disable=SC2016
set -euo pipefail

# TODO: one-line description of this flow
# TODO: what layout/screenshot change means success (e.g. --find "Settings" on title bar)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SK="${ROOT}/.agents/skills/android-cli-layout-tap/scripts"
DEVICE="${ANDROID_SERIAL:-emulator-5554}"
POLL_SEC="${POLL_SEC:-5}"
MAX_ROUNDS="${MAX_ROUNDS:-24}"

if [[ -n "${ANDROID_HOME:-}" ]]; then
  export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/emulator:${ANDROID_HOME}/platform-tools:${PATH}"
fi

android() { command android "$@"; }
adb() { command adb -s "$DEVICE" "$@"; }

# --- actions: replace with your sequence ---

tap_by_find() {
  local label=$1
  bash "$SK/layout_tap_run.sh" "$DEVICE" --find "$label"
}

wait_for_layout_find() {
  local label=$1
  local round
  for ((round = 1; round <= MAX_ROUNDS; round++)); do
    if bash "$SK/layout_stream_tap.sh" "$DEVICE" --find "$label" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$POLL_SEC"
  done
  return 1
}

# Example: tap then poll until a success marker appears in the layout
# tap_by_find "Profile" || exit 1
# sleep 1
# if wait_for_layout_find "Account"; then
#   echo "ok: success UI visible"
#   exit 0
# fi
# echo "timeout waiting for success UI" >&2
# exit 1

echo "Copy this file to a new name, replace the example block with real steps, and delete this message." >&2
exit 1
