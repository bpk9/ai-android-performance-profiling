#!/usr/bin/env bash
# Tap by --find LABEL only if no matching node already has STATE (default: selected).
# One layout dump per invocation (fast vs calling stream_tap + tap_run separately).
#
# Usage: tap_unless_selected.sh <device-serial> <find-label> [state-substring]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=layout_common.sh
source "${ROOT}/layout_common.sh"
layout_common_require_node

DEVICE="${1:?Usage: $0 <device-serial> <find-label> [state-substring]}"
FIND_LABEL="${2:?Usage: $0 <device-serial> <find-label> [state-substring]}"
STATE_SUB="${3:-selected}"

tmp="$(mktemp "${TMPDIR:-/tmp}/android-layout.${DEVICE//[^a-zA-Z0-9._-]/_}.XXXXXX")"
cleanup() { rm -f "${tmp:-}"; }
trap cleanup EXIT

android layout --device="$DEVICE" -p >"$tmp"

if "${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" -f "$tmp" --find "$FIND_LABEL" --state-contains "$STATE_SUB" >/dev/null 2>&1; then
  if [[ "${LAYOUT_TAP_VERBOSE:-}" == "1" ]]; then
    echo "tap_unless_selected: skip (already ${STATE_SUB}): ${FIND_LABEL}" >&2
  fi
  exit 0
fi

out="$("${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" -f "$tmp" --find "$FIND_LABEL")" || exit $?
if ! [[ "$out" =~ ^[0-9]+[[:space:]]+[0-9]+$ ]]; then
  echo "tap_unless_selected: expected coordinate line 'x y' on stdout" >&2
  exit 2
fi

read -r X Y <<<"$out"
exec adb -s "$DEVICE" shell input tap "$X" "$Y"
