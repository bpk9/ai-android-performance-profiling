#!/usr/bin/env bash
# Create an iOS simulator device if missing. Env: IOS_SIM_NAME (default ExpoPerfIOS),
# IOS_DEVICE_TYPE (optional; defaults to best flagship iPhone available),
# IOS_RUNTIME (optional; defaults to latest available iOS runtime).

set -euo pipefail

SIM_NAME="${IOS_SIM_NAME:-ExpoPerfIOS}"

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "error: iOS Simulator requires macOS" >&2
  exit 1
}
command -v xcrun >/dev/null || {
  echo "error: xcrun not found; install Xcode and run 'xcode-select --install'" >&2
  exit 1
}

if xcrun simctl list devices 2>/dev/null | grep -Fq "    ${SIM_NAME} ("; then
  echo "Simulator '${SIM_NAME}' already exists; skipping."
  exit 0
fi

if [[ -z "${IOS_DEVICE_TYPE:-}" ]]; then
  catalog=$(xcrun simctl list devicetypes 2>/dev/null || true)
  # Prefer newest large-flagship iPhones so emulated display/RAM defaults are less likely to cap profiling.
  for id in \
    com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max \
    com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
    com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max \
    com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro \
    com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro-Max \
    com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro; do
    if echo "$catalog" | grep -Fq "$id"; then
      DEVICE_TYPE=$id
      break
    fi
  done
  DEVICE_TYPE=${DEVICE_TYPE:-$(echo "$catalog" | grep -oE 'com\.apple\.CoreSimulator\.SimDeviceType\.iPhone-[A-Za-z0-9-]+' | tail -n 1)}
else
  DEVICE_TYPE=$IOS_DEVICE_TYPE
fi
[[ -n "${DEVICE_TYPE:-}" ]] || { echo "error: no iPhone device type found in Xcode" >&2; exit 1; }
echo "device type: ${DEVICE_TYPE}"

if [[ -z "${IOS_RUNTIME:-}" ]]; then
  RUNTIME=$(xcrun simctl list runtimes available 2>/dev/null \
    | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9]+-[0-9]+' \
    | sort -V | tail -n 1)
else
  RUNTIME=$IOS_RUNTIME
fi
[[ -n "${RUNTIME:-}" ]] || {
  echo "error: no iOS runtime installed; add one in Xcode > Settings > Platforms" >&2
  exit 1
}
echo "runtime: ${RUNTIME}"

udid=$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE" "$RUNTIME")
echo "Created '${SIM_NAME}' (${udid}). Run: scripts/open_ios_sim.sh"
