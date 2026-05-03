#!/usr/bin/env bash
# Bottom nav: open Long list, then fast-swipe until the last row appears in the layout tree.
# Uses wm size for swipe coordinates (works across emulator resolutions).
# Prerequisite: app is in the foreground on the device.
# Success: accessibility layout includes the final list label (see LONG_LIST_ROW_COUNT).
#
# Unvirtualized lists often expose every row in one layout dump, so this script also enforces
# MIN_TOWARD_END_SWIPES fast swipes before success (set 0 to rely only on layout match).
#
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SK="${ROOT}/.agents/skills/android-cli-layout-tap/scripts"
DEVICE="${ANDROID_SERIAL:-emulator-5554}"

# Keep in sync with app/app/(tabs)/longlist.tsx LONG_LIST_ROW_COUNT
LONG_LIST_ROW_COUNT=1200
LAST_INDEX=$((LONG_LIST_ROW_COUNT - 1))
LAST_LABEL="$(printf 'List item %03d' "$LAST_INDEX")"

MAX_SWIPES="${MAX_SWIPES:-80}"
MIN_TOWARD_END_SWIPES="${MIN_TOWARD_END_SWIPES:-12}"
SWIPE_DURATION_MS="${SWIPE_DURATION_MS:-35}"
SWIPE_SLEEP_SEC="${SWIPE_SLEEP_SEC:-0.08}"

if [[ -n "${ANDROID_HOME:-}" ]]; then
  export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/emulator:${ANDROID_HOME}/platform-tools:${PATH}"
fi

# shellcheck source=../../.agents/skills/android-cli-layout-tap/scripts/layout_common.sh
source "$SK/layout_common.sh"
layout_common_require_node

adb() { command adb -s "$DEVICE" "$@"; }

# Finger moves up → content scrolls toward the end of the list.
fast_scroll_toward_end() {
  local line wh w h mx y_bottom y_top
  line="$(adb shell wm size 2>/dev/null || true)"
  wh="$(echo "$line" | grep -oE '[0-9]+x[0-9]+' | head -1)"
  w="${wh%x*}"
  h="${wh#*x}"
  if [[ -z "${w:-}" || -z "${h:-}" ]]; then
    echo "longlist-scroll-to-end-flow: could not parse wm size from: $line" >&2
    exit 1
  fi
  mx=$((w / 2))
  y_bottom=$((h * 88 / 100))
  y_top=$((h * 12 / 100))
  adb shell input swipe "$mx" "$y_bottom" "$mx" "$y_top" "$SWIPE_DURATION_MS"
}

last_row_in_layout() {
  bash "$SK/layout_cli.sh" coords "$DEVICE" --find "$LAST_LABEL" >/dev/null 2>&1
}

bash "$SK/tap_unless_selected.sh" "$DEVICE" "Long list"
/bin/sleep 1

toward_end=0
for ((round = 0; round < MAX_SWIPES; round++)); do
  if (( toward_end >= MIN_TOWARD_END_SWIPES )) && last_row_in_layout; then
    echo "ok: ${LAST_LABEL} in layout after ${toward_end} fast toward-end swipe(s) (min ${MIN_TOWARD_END_SWIPES})"
    exit 0
  fi
  fast_scroll_toward_end
  toward_end=$((toward_end + 1))
  /bin/sleep "$SWIPE_SLEEP_SEC"
done

echo "timeout: ${LAST_LABEL} not matched after ${toward_end} toward-end swipe(s) (raise MAX_SWIPES or check tab / LONG_LIST_ROW_COUNT)" >&2
exit 1
