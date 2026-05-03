#!/usr/bin/env bash
# Record a Perfetto trace to a local file via adb exec-out (avoids /data/local/tmp permission issues).
# Open the .perfetto file at https://ui.perfetto.dev — enables FrameTimeline / scheduling vs gfxinfo alone.
#
# Usage: perfetto_record_android.sh [output.perfetto]
# Env: ANDROID_SERIAL, ANDROID_PACKAGE (for --app), PERFETTO_SEC (default 12), PERFETTO_BUFFER_MB (64),
#      PERFETTO_CATEGORIES (default: gfx sched view wm idle)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${ANDROID_SERIAL:-emulator-5554}"
PKG="${ANDROID_PACKAGE:-com.aiandroidperformance.app}"
SEC="${PERFETTO_SEC:-12}"
BUF_MB="${PERFETTO_BUFFER_MB:-64}"
# shellcheck disable=SC2206
IFS=' ' read -r -a CATS <<<"${PERFETTO_CATEGORIES:-gfx sched view wm idle}"

OUT="${1:-$ROOT/.metrics/perfetto/trace-$(date +%Y%m%d-%H%M%S).perfetto}"
mkdir -p "$(dirname "$OUT")"

echo "Recording ${SEC}s for package ${PKG}; categories: ${CATS[*]}" >&2
echo "Perform your gesture NOW (e.g. scroll Long list)..." >&2

# -o - streams trace protobuf to stdout. Drop device stderr so log lines are not mixed into the file.
cats_joined="${CATS[*]}"
adb -s "$DEVICE" exec-out sh -c "perfetto -t ${SEC}s -b ${BUF_MB}mb ${cats_joined} --app ${PKG} -o - 2>/dev/null" >"$OUT"

echo "Wrote $OUT — open in https://ui.perfetto.dev (Android 12+: FrameTimeline / jank attribution)." >&2
