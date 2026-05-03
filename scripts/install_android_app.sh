#!/usr/bin/env bash
# Install the built APK onto a USB emulator or device via adb.
# Env: ANDROID_SERIAL (adb device id when multiple devices),
# ANDROID_BUILD_VARIANT (debug | debugOptimized | release; default debugOptimized; must match build).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/app"

VARIANT="${ANDROID_BUILD_VARIANT:-debugOptimized}"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -z "$SDK_ROOT" && -d "$HOME/Library/Android/sdk" ]] && SDK_ROOT="$HOME/Library/Android/sdk"
[[ -z "$SDK_ROOT" && -d "$HOME/Android/Sdk" ]] && SDK_ROOT="$HOME/Android/Sdk"
[[ -n "${SDK_ROOT:-}" && -d "$SDK_ROOT" ]] || {
  echo "error: Android SDK not found; set ANDROID_HOME or ANDROID_SDK_ROOT" >&2
  exit 1
}
export PATH="$SDK_ROOT/platform-tools:$PATH"

command -v adb >/dev/null || {
  echo "error: adb not found in PATH ($SDK_ROOT/platform-tools)" >&2
  exit 1
}

ADB=(adb)
[[ -n "${ANDROID_SERIAL:-}" ]] && ADB=(adb -s "$ANDROID_SERIAL")

case "$VARIANT" in
  debug)
    APK="$APP_DIR/android/app/build/outputs/apk/debug/app-debug.apk"
    ;;
  debugOptimized)
    APK="$APP_DIR/android/app/build/outputs/apk/debugOptimized/app-debugOptimized.apk"
    ;;
  release)
    APK="$APP_DIR/android/app/build/outputs/apk/release/app-release.apk"
    ;;
  *)
    echo "error: ANDROID_BUILD_VARIANT must be debug, debugOptimized, or release (got $VARIANT)" >&2
    exit 1
    ;;
esac

[[ -f "$APK" ]] || {
  echo "error: APK not found: $APK" >&2
  echo "Run: $REPO_ROOT/scripts/build_android_app.sh" >&2
  exit 1
}

device_count=$("${ADB[@]}" devices 2>/dev/null | awk 'NR>1 && $2=="device" {c++} END {print c+0}')
if [[ "$device_count" -eq 0 ]]; then
  echo "error: no device/emulator in 'adb devices' (state must be 'device')" >&2
  exit 1
fi
if [[ -z "${ANDROID_SERIAL:-}" && "$device_count" -gt 1 ]]; then
  echo "Multiple devices:" >&2
  "${ADB[@]}" devices -l >&2
  echo "Set ANDROID_SERIAL to the device id you want." >&2
  exit 1
fi

echo "Installing $APK ..."
"${ADB[@]}" install -r "$APK"
