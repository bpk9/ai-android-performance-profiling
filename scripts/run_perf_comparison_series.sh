#!/usr/bin/env bash
# Run collect_android_gfxinfo_compare.sh multiple times; aggregate metrics with 95% CI for the mean.
#
# Env: ITERATIONS (default 15), PERF_METRICS_OUT (base directory), ANDROID_SERIAL, ANDROID_PACKAGE,
#      BASELINE_IDLE_SEC, plus vars consumed by collect_android_gfxinfo_compare.sh / longlist flow.
#
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ITERATIONS="${ITERATIONS:-15}"
BASE="${PERF_METRICS_OUT:-$ROOT/.metrics/gfx-compare-series-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$BASE"

echo "Writing runs under $BASE (${ITERATIONS} iterations)" >&2

for ((i = 1; i <= ITERATIONS; i++)); do
  R="$BASE/run_$(printf '%03d' "$i")"
  mkdir -p "$R"
  echo "" >&2
  echo "==================== iteration $i / $ITERATIONS ====================" >&2
  if OUTPUT_DIR="$R" bash "$ROOT/scripts/collect_android_gfxinfo_compare.sh"; then
    echo "ok run $i" >&2
  else
    echo "warning: iteration $i exited non-zero (partial artifacts may exist)" >&2
  fi
done

echo "" >&2
python3 "$ROOT/scripts/aggregate_perf_runs.py" "$BASE"
