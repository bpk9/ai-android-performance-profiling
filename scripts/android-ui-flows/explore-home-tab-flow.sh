#!/usr/bin/env bash
# Bottom nav: open Explore, then return to Home.
# Uses accessibility state so we do not send a redundant tap if a tab is already selected.
# Success: Home tab selected (optional layout or screenshot check).
#
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SK="${ROOT}/.agents/skills/android-cli-layout-tap/scripts"
DEVICE="${ANDROID_SERIAL:-emulator-5554}"

bash "$SK/tap_unless_selected.sh" "$DEVICE" Explore
/bin/sleep 1
bash "$SK/tap_unless_selected.sh" "$DEVICE" Home
