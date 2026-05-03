#!/usr/bin/env bash
# Unified entry for layout dump → layout_find_tap.mjs → adb (see SKILLS.md).
# Thin wrappers (layout_tap_run.sh, layout_stream_tap.sh, …) delegate here.
#
# Commands:
#   tap <serial> [--reuse-layout FILE] [<layout_find_tap.mjs args>]
#   coords <serial> [--reuse-layout FILE] [<layout_find_tap.mjs args>]
#   labels <serial> [--reuse-layout FILE] [<extra args>]  → --list-all-labels
#   dump <serial> [out.json]                             → print path only
#   batch-tap <serial> [--reuse-layout FILE] [--sleep SEC] (--batch-json FILE | STEPS.json)
#
# Env: LAYOUT_TAP_USE_PIPE=1 — stream android layout | node (no temp file) when not using --reuse-layout.
#      LAYOUT_TAP_BATCH_SLEEP — default gap between batch taps (default 0.35); batch-tap --sleep overrides.
#
set -euo pipefail
set -o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=layout_common.sh
source "${ROOT}/layout_common.sh"

LAYOUT_TMP=""
LAYOUT_TMP_MANAGED=0

usage() {
  cat >&2 <<'EOF'
layout_cli.sh — unified Android layout helpers

  tap <serial> [--reuse-layout FILE] [<layout_find_tap.mjs args>]
  coords <serial> [--reuse-layout FILE] [<layout_find_tap.mjs args>]
  labels <serial> [--reuse-layout FILE] [<extra>]   → --list-all-labels
  dump <serial> [out.json]
  batch-tap <serial> [--reuse-layout FILE] [--sleep SEC] (--batch-json FILE | STEPS.json)

LAYOUT_TAP_USE_PIPE=1 uses android layout | node (no temp file) when --reuse-layout is not set.
EOF
  exit 2
}

finish_layout_tmp() {
  if [[ "$LAYOUT_TMP_MANAGED" == "1" && -n "$LAYOUT_TMP" ]]; then
    rm -f "$LAYOUT_TMP"
    LAYOUT_TMP=""
    LAYOUT_TMP_MANAGED=0
  fi
}

run_layout_temp_or_reuse() {
  local device="$1"
  local reuse="${2:-}"
  LAYOUT_TMP=""
  LAYOUT_TMP_MANAGED=0
  if [[ -n "$reuse" ]]; then
    if [[ ! -f "$reuse" ]]; then
      echo "layout_cli: --reuse-layout file not found: $reuse" >&2
      exit 2
    fi
    LAYOUT_TMP="$reuse"
    return 0
  fi
  LAYOUT_TMP="$(mktemp "${TMPDIR:-/tmp}/android-layout.${device//[^a-zA-Z0-9._-]/_}.XXXXXX")"
  LAYOUT_TMP_MANAGED=1
  android layout --device="$device" -p >"$LAYOUT_TMP"
}

cmd_tap() {
  layout_common_require_node
  local device="$1"
  shift
  local reuse=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reuse-layout)
        reuse="${2:?}"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done
  local node_args=("$@")

  if [[ "${LAYOUT_TAP_USE_PIPE:-}" == "1" && -z "$reuse" ]]; then
    local out
    out="$(android layout --device="$device" -p | "${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" "${node_args[@]}")" || exit $?
    if ! [[ "$out" =~ ^[0-9]+[[:space:]]+[0-9]+$ ]]; then
      echo "layout_cli tap: expected coordinate line 'x y' on stdout; omit --json/--list/--adb/--list-all-labels" >&2
      echo "Got: ${out:0:120}" >&2
      exit 2
    fi
    local X Y
    read -r X Y <<<"$out"
    exec adb -s "$device" shell input tap "$X" "$Y"
  fi

  trap finish_layout_tmp EXIT
  run_layout_temp_or_reuse "$device" "$reuse"

  local out
  out="$("${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" -f "$LAYOUT_TMP" "${node_args[@]}")" || exit $?
  if ! [[ "$out" =~ ^[0-9]+[[:space:]]+[0-9]+$ ]]; then
    echo "layout_cli tap: expected coordinate line 'x y' on stdout" >&2
    echo "Got: ${out:0:120}" >&2
    exit 2
  fi
  local X Y
  read -r X Y <<<"$out"
  finish_layout_tmp
  trap - EXIT
  exec adb -s "$device" shell input tap "$X" "$Y"
}

cmd_coords() {
  layout_common_require_node
  local device="$1"
  shift
  local reuse=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reuse-layout)
        reuse="${2:?}"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done
  local node_args=("$@")

  if [[ "${LAYOUT_TAP_USE_PIPE:-}" == "1" && -z "$reuse" ]]; then
    android layout --device="$device" -p | "${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" "${node_args[@]}"
    return
  fi

  trap finish_layout_tmp EXIT
  run_layout_temp_or_reuse "$device" "$reuse"
  local code=0
  "${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" -f "$LAYOUT_TMP" "${node_args[@]}" || code=$?
  finish_layout_tmp
  trap - EXIT
  exit "$code"
}

cmd_labels() {
  layout_common_require_node
  local device="$1"
  shift
  local reuse=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reuse-layout)
        reuse="${2:?}"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done
  local node_args=("$@")

  if [[ "${LAYOUT_TAP_USE_PIPE:-}" == "1" && -z "$reuse" ]]; then
    android layout --device="$device" -p | "${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" --list-all-labels "${node_args[@]}"
    return
  fi

  trap finish_layout_tmp EXIT
  run_layout_temp_or_reuse "$device" "$reuse"
  local code=0
  "${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" -f "$LAYOUT_TMP" --list-all-labels "${node_args[@]}" || code=$?
  finish_layout_tmp
  trap - EXIT
  exit "$code"
}

cmd_dump() {
  layout_common_prepend_path
  local device="$1"
  shift
  local safe="${device//[^a-zA-Z0-9._-]/_}"
  local OUT="${1:-${TMPDIR:-/tmp}/android-layout-${safe}-$$.json}"
  android layout --device="$device" -p >"$OUT"
  echo "$OUT"
}

cmd_batch_tap() {
  layout_common_require_node
  local device="$1"
  shift
  local reuse=""
  local sleep_between="${LAYOUT_TAP_BATCH_SLEEP:-0.35}"
  local batch_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reuse-layout)
        reuse="${2:?}"
        shift 2
        ;;
      --sleep)
        sleep_between="${2:?}"
        shift 2
        ;;
      --batch-json)
        batch_file="${2:?}"
        shift 2
        ;;
      *)
        if [[ -z "$batch_file" && -f "$1" ]]; then
          batch_file="$1"
          shift
          continue
        fi
        echo "layout_cli: unexpected argument: $1" >&2
        usage
        ;;
    esac
  done
  if [[ -z "$batch_file" || ! -f "$batch_file" ]]; then
    echo "layout_cli: batch-tap needs --batch-json FILE or a path to an existing JSON file." >&2
    exit 2
  fi

  trap finish_layout_tmp EXIT
  run_layout_temp_or_reuse "$device" "$reuse"

  local lines=()
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    lines+=("$line")
  done < <("${LAYOUT_FIND_TAP_NODE_CMD}" "${ROOT}/layout_find_tap.mjs" -f "$LAYOUT_TMP" --batch-json "$batch_file")

  finish_layout_tmp
  trap - EXIT

  local n="${#lines[@]}"
  if [[ "$n" -eq 0 ]]; then
    echo "layout_cli batch-tap: no coordinate lines from batch run" >&2
    exit 2
  fi

  local i=0
  for line in "${lines[@]}"; do
    local X Y
    read -r X Y <<<"$line"
    adb -s "$device" shell input tap "$X" "$Y"
    i=$((i + 1))
    if [[ "$i" -lt "$n" ]]; then
      sleep "$sleep_between"
    fi
  done
}

main() {
  local sub="${1:-}"
  [[ -n "$sub" ]] || usage
  shift
  case "$sub" in
    tap) cmd_tap "$@" ;;
    coords) cmd_coords "$@" ;;
    labels) cmd_labels "$@" ;;
    dump) cmd_dump "$@" ;;
    batch-tap) cmd_batch_tap "$@" ;;
    help | -h | --help) usage ;;
    *)
      echo "layout_cli: unknown command: $sub" >&2
      usage
      ;;
  esac
}

main "$@"
