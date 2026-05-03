#!/usr/bin/env bash
# Shared setup for layout helper scripts: PATH, adb/android, Node for layout_find_tap.mjs.
# shellcheck disable=SC2034  # LAYOUT_FIND_TAP_NODE_CMD used by callers after source

layout_common_prepend_path() {
  export PATH="/usr/bin:/bin:${PATH:-}"

  if [[ -n "${ANDROID_HOME:-}" ]]; then
    PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator:${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"
  fi
  # Common installs (macOS / Linux); harmless if missing.
  for extra in \
    "${HOME}/Library/Android/sdk/platform-tools" \
    "${HOME}/Library/Android/sdk/emulator" \
    "${HOME}/Library/Android/sdk/cmdline-tools/latest/bin" \
    "${HOME}/bin"; do
    [[ -d "$extra" ]] && PATH="${extra}:${PATH}"
  done
  export PATH
}

layout_common_bootstrap() {
  layout_common_prepend_path

  LAYOUT_FIND_TAP_NODE_CMD=""
  if [[ -n "${LAYOUT_FIND_TAP_NODE:-}" && -x "${LAYOUT_FIND_TAP_NODE}" ]]; then
    LAYOUT_FIND_TAP_NODE_CMD="${LAYOUT_FIND_TAP_NODE}"
    return 0
  fi
  if [[ -n "${NODE_BIN:-}" && -x "${NODE_BIN}" ]]; then
    LAYOUT_FIND_TAP_NODE_CMD="${NODE_BIN}"
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    LAYOUT_FIND_TAP_NODE_CMD="$(command -v node)"
    return 0
  fi
  if [[ -d "${HOME}/.nvm/versions/node" ]]; then
    local latest
    latest="$(find "${HOME}/.nvm/versions/node" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)"
    if [[ -n "$latest" && -x "$latest/bin/node" ]]; then
      LAYOUT_FIND_TAP_NODE_CMD="$latest/bin/node"
      return 0
    fi
  fi
  if [[ -x "/opt/homebrew/bin/node" ]]; then
    LAYOUT_FIND_TAP_NODE_CMD="/opt/homebrew/bin/node"
    return 0
  fi
  if [[ -x "/usr/local/bin/node" ]]; then
    LAYOUT_FIND_TAP_NODE_CMD="/usr/local/bin/node"
    return 0
  fi
  return 1
}

layout_common_require_node() {
  if ! layout_common_bootstrap; then
    echo "layout_common: node not found. Install Node.js, put it on PATH, or set LAYOUT_FIND_TAP_NODE (or NODE_BIN)." >&2
    exit 127
  fi
}
