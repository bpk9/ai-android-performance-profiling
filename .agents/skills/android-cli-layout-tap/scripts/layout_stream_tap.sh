#!/usr/bin/env bash
# android layout → layout_find_tap.mjs (stdout only). Delegates to layout_cli.sh coords.
# Usage: layout_stream_tap.sh <device-serial> [--reuse-layout FILE] [layout_find_tap.mjs options...]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${ROOT}/layout_cli.sh" coords "$@"
