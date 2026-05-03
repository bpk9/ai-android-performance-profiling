#!/usr/bin/env bash
# Run Metro's symbolicator against the *current* dev source map (see metro_dev_fetch_sourcemap.sh).
# Passes through all arguments to metro-symbolicate after the map path.
#
# Examples (from repo root, Metro on 8081):
#   echo 'http://127.0.0.1:8081/node_modules/expo-router/entry.bundle?platform=android&dev=true&minify=false:196182:10' | ./scripts/metro_dev_symbolicate.sh
#   ./scripts/metro_dev_symbolicate.sh 196182 10
#   ./scripts/metro_dev_symbolicate.sh /path/to/profile.cpuprofile
#
# Env: same as metro_dev_fetch_sourcemap.sh. You can also set METRO_DEV_SOURCE_MAP to an existing
#      .map file to skip the download.
#
# shellcheck disable=SC2093
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app"

if [[ -n "${METRO_DEV_SOURCE_MAP:-}" ]]; then
  MAP="$METRO_DEV_SOURCE_MAP"
else
  MAP="$(METRO_SOURCEMAP_CACHE="${METRO_SOURCEMAP_CACHE:-}" METRO_HOST="${METRO_HOST:-}" METRO_PORT="${METRO_PORT:-}" METRO_ENTRY="${METRO_ENTRY:-}" METRO_BUNDLE_QUERY="${METRO_BUNDLE_QUERY:-}" METRO_FETCH_FORCE="${METRO_FETCH_FORCE:-}" METRO_FETCH_TIMEOUT_SEC="${METRO_FETCH_TIMEOUT_SEC:-}" bash "$ROOT/scripts/metro_dev_fetch_sourcemap.sh")"
fi

cd "$APP_DIR"
exec npx metro-symbolicate "$MAP" "$@"
