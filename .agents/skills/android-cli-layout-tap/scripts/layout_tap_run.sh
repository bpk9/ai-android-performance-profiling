#!/usr/bin/env bash
# Fresh layout → resolve tap coordinates → adb tap. Delegates to layout_cli.sh (single implementation).
# Usage: layout_tap_run.sh <device-serial> [--reuse-layout FILE] [layout_find_tap.mjs options...]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${ROOT}/layout_cli.sh" tap "$@"
