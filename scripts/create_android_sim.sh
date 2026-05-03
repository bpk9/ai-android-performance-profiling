#!/usr/bin/env bash
# Create an AVD if missing. Env: ANDROID_AVD_NAME, ANDROID_API_LEVEL,
# ANDROID_DEVICE_PROFILE (optional; defaults to best flagship profile available),
# ANDROID_ABI_OVERRIDE, ANDROID_SDK_ROOT / ANDROID_HOME.

set -euo pipefail

AVD_NAME="${ANDROID_AVD_NAME:-ExpoPerf}"
API_LEVEL="${ANDROID_API_LEVEL:-36}"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -z "$SDK_ROOT" && -d "$HOME/Library/Android/sdk" ]] && SDK_ROOT="$HOME/Library/Android/sdk"
[[ -z "$SDK_ROOT" && -d "$HOME/Android/Sdk" ]] && SDK_ROOT="$HOME/Android/Sdk"
[[ -n "${SDK_ROOT:-}" && -d "$SDK_ROOT" ]] || {
  echo "error: Android SDK not found; set ANDROID_HOME or ANDROID_SDK_ROOT" >&2
  exit 1
}

for d in "$SDK_ROOT/cmdline-tools/latest/bin" "$SDK_ROOT/cmdline-tools/bin"; do
  [[ -d "$d" ]] && PATH="$d:$PATH" && break
done
command -v avdmanager >/dev/null || {
  echo "error: cmdline-tools missing under $SDK_ROOT/cmdline-tools" >&2
  exit 1
}
export PATH="$SDK_ROOT/emulator:$SDK_ROOT/platform-tools:$PATH"

if [[ -z "${ANDROID_DEVICE_PROFILE:-}" ]]; then
  device_catalog=$(avdmanager list device 2>/dev/null || true)
  # Prefer newest large-flagship profiles so emulated RAM/display defaults are less likely to cap profiling.
  for id in pixel_10_pro_xl pixel_10_pro pixel_9_pro_xl pixel_9_pro; do
    if echo "$device_catalog" | grep -Fq "\"$id\""; then
      DEVICE_PROFILE=$id
      break
    fi
  done
  DEVICE_PROFILE=${DEVICE_PROFILE:-pixel_9}
else
  DEVICE_PROFILE=$ANDROID_DEVICE_PROFILE
fi
echo "hardware profile: ${DEVICE_PROFILE}"

abi="${ANDROID_ABI_OVERRIDE:-}"
[[ -z "$abi" ]] && case "$(uname -m)" in arm64|aarch64) abi=arm64-v8a ;; *) abi=x86_64 ;; esac
pkg="system-images;android-${API_LEVEL};google_apis;${abi}"

while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*Name:[[:space:]]*(.+)$ ]] && [[ "${BASH_REMATCH[1]}" == "$AVD_NAME" ]]; then
    echo "AVD '${AVD_NAME}' already exists; skipping."
    exit 0
  fi
done < <(avdmanager list avd 2>/dev/null || true)

sdkmanager "platform-tools" "emulator" "$pkg"

echo no | avdmanager create avd -n "$AVD_NAME" -k "$pkg" -d "$DEVICE_PROFILE"

echo "Created '${AVD_NAME}'. Run: emulator -avd '${AVD_NAME}'"
