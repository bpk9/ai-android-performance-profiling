#!/usr/bin/env bash
# Dump layout and --list-all-labels. Delegates to layout_cli.sh labels.
# Usage: layout_labels.sh <device-serial> [--reuse-layout FILE] [layout_find_tap.mjs options...]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${ROOT}/layout_cli.sh" labels "$@"
