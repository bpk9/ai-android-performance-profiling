#!/usr/bin/env bash
# Reset gfxinfo, measure (1) idle on Home tab vs (2) long-list fast-scroll flow, print comparable lines.
# Confirms higher jank / frame time / view count on the unvirtualized list path.
#
# Prereq: app installed and in foreground; device serial via ANDROID_SERIAL (default emulator-5554).
# Env: ANDROID_PACKAGE (default from app/app.json), BASELINE_IDLE_SEC, OUTPUT_DIR (optional full dumps).
#
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SK="${ROOT}/.agents/skills/android-cli-layout-tap/scripts"
DEVICE="${ANDROID_SERIAL:-emulator-5554}"
PKG="${ANDROID_PACKAGE:-com.aiandroidperformance.app}"
BASELINE_IDLE_SEC="${BASELINE_IDLE_SEC:-5}"

OUT_DIR="${OUTPUT_DIR:-}"
if [[ -n "$OUT_DIR" && "$OUT_DIR" != /* ]]; then
  OUT_DIR="$ROOT/$OUT_DIR"
fi

adb() { command adb -s "$DEVICE" "$@"; }

gfx_reset() {
  adb shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1 || true
}

gfx_full_dump() {
  adb shell dumpsys gfxinfo "$PKG" 2>/dev/null
}

# Lines useful for A/B without dumping megabytes into the terminal.
gfx_extract_summary() {
  gfx_full_dump | grep -E \
    '^Total frames rendered:|^Janky frames: [0-9]|^50th percentile:|^90th percentile:|^95th percentile:|^99th percentile:|^Number Missed Vsync:|^Number Slow UI thread:|^Total attached Views :|^\s+[0-9]+ views,' \
    || true
}

mem_total_line() {
  adb shell dumpsys meminfo "$PKG" 2>/dev/null | grep -E '^[[:space:]]+TOTAL[[:space:]]' | head -1 || true
}

section() {
  echo ""
  echo "=== $* ==="
}

dump_and_save() {
  local slug=$1
  local title=${2:-$1}
  section "$title"
  gfx_extract_summary
  echo "meminfo TOTAL:" "$(mem_total_line)"
  if [[ -n "$OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
    local f="$OUT_DIR/gfxinfo-${slug}.txt"
    gfx_full_dump >"$f" || true
    adb shell dumpsys meminfo "$PKG" >"$OUT_DIR/meminfo-${slug}.txt" || true
    echo "(full: $f)" >&2
  fi
}

if ! adb shell pidof "$PKG" >/dev/null 2>&1; then
  echo "error: $PKG is not running on $DEVICE; start the app first." >&2
  exit 1
fi

# --- A: light UI (Home) ---
gfx_reset
bash "$SK/tap_unless_selected.sh" "$DEVICE" "Home" || true
/bin/sleep "$BASELINE_IDLE_SEC"
dump_and_save "A_baseline_home" "A baseline — Home tab (idle ${BASELINE_IDLE_SEC}s after select)"

# --- B: long list + fast scroll ---
gfx_reset
bash "$ROOT/scripts/android-ui-flows/longlist-scroll-to-end-flow.sh"
dump_and_save "B_longlist_after_scroll" "B long list — after longlist-scroll-to-end-flow.sh"

section "Readout"
echo "Strongest signal here is usually view hierarchy size: Total attached Views and the 'N views, … render nodes' line"
echo "jump when the Long list tab mounts hundreds of unvirtualized rows (often ~10–20x vs Home)."
echo "meminfo TOTAL PSS/RSS may rise with that workload."
echo "Janky % / percentiles depend on frames since the last gfx reset — compare when Total frames rendered is similar,"
echo "or run longer interactions / repeat phase B."
