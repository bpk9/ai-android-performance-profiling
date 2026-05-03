#!/usr/bin/env bash
# Boot the iOS simulator from create_ios_sim.sh and open Simulator.app.
# Env: IOS_SIM_NAME (default ExpoPerfIOS).

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

if ! xcrun simctl list devices 2>/dev/null | grep -Fq "    ${SIM_NAME} ("; then
  echo "error: no simulator named '${SIM_NAME}'. Run: scripts/create_ios_sim.sh" >&2
  exit 1
fi

UDID=$(xcrun simctl list devices 2>/dev/null \
  | grep -E "^\s+${SIM_NAME} \(" \
  | grep -oE '[0-9A-F-]{36}' | head -n 1)
[[ -n "$UDID" ]] || { echo "error: could not resolve UDID for '${SIM_NAME}'" >&2; exit 1; }

open -a Simulator --args -CurrentDeviceUDID "$UDID"
exec xcrun simctl bootstatus "$UDID" -b
