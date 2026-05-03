#!/usr/bin/env bash
# Start the Android emulator for the AVD from create_android_sim.sh.
# Env: ANDROID_AVD_NAME (default ExpoPerf), ANDROID_HOME / ANDROID_SDK_ROOT.
# Pass-through: any args are forwarded to `emulator` (e.g. -no-snapshot for cold boot).

set -euo pipefail

AVD_NAME="${ANDROID_AVD_NAME:-ExpoPerf}"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -z "$SDK_ROOT" && -d "$HOME/Library/Android/sdk" ]] && SDK_ROOT="$HOME/Library/Android/sdk"
[[ -z "$SDK_ROOT" && -d "$HOME/Android/Sdk" ]] && SDK_ROOT="$HOME/Android/Sdk"
[[ -n "${SDK_ROOT:-}" && -d "$SDK_ROOT" ]] || {
  echo "error: Android SDK not found; set ANDROID_HOME or ANDROID_SDK_ROOT" >&2
  exit 1
}
export PATH="$SDK_ROOT/emulator:$SDK_ROOT/platform-tools:$PATH"

command -v emulator >/dev/null || {
  echo "error: emulator not found under $SDK_ROOT/emulator; install the emulator package" >&2
  exit 1
}

if ! emulator -list-avds 2>/dev/null | grep -qxF "$AVD_NAME"; then
  echo "error: no AVD named '${AVD_NAME}'. Run: scripts/create_android_sim.sh" >&2
  exit 1
fi

exec emulator -avd "$AVD_NAME" "$@"
