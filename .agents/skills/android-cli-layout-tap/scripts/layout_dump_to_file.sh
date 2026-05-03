#!/usr/bin/env bash
# Write android layout JSON to a file; stdout is the path only. Delegates to layout_cli.sh dump.
# Usage: layout_dump_to_file.sh <device-serial> [output.json]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${ROOT}/layout_cli.sh" dump "$@"
