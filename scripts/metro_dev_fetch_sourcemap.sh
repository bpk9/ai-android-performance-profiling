#!/usr/bin/env bash
# Download the JavaScript source map that pairs with Metro's *current* dev bundle for this app.
#
# Metro serves bundle + map at predictable URLs (same query string; path differs only by
# .bundle vs .map). This avoids downloading the multi‑MB bundle just to read //# sourceMappingURL.
#
# Prerequisites: Metro running (e.g. `npm start` in app/), default http://127.0.0.1:8081
#
# Usage:  metro_dev_fetch_sourcemap.sh
# Stdout: absolute path to the cached .map file
# Env (all optional):
#   METRO_HOST (default 127.0.0.1)   METRO_PORT (default 8081)
#   METRO_ENTRY (default node_modules/expo-router/entry) — must match app package.json "main" / router
#   METRO_BUNDLE_QUERY (default platform=android&dev=true&minify=false) — must match the device / profile
#   METRO_SOURCEMAP_CACHE — override cache dir (default: app/.metro-sourcemap-cache)
#   METRO_FETCH_FORCE=1 — re-download even if cache file exists
#
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app"
HOST="${METRO_HOST:-127.0.0.1}"
PORT="${METRO_PORT:-8081}"
ENTRY="${METRO_ENTRY:-node_modules/expo-router/entry}"
QUERY="${METRO_BUNDLE_QUERY:-platform=android&dev=true&minify=false}"
BASE="http://${HOST}:${PORT}"

MAP_URL="${BASE}/${ENTRY}.map?${QUERY}"
BUNDLE_URL="${BASE}/${ENTRY}.bundle?${QUERY}"

CACHE_ROOT="${METRO_SOURCEMAP_CACHE:-$APP_DIR/.metro-sourcemap-cache}"
mkdir -p "$CACHE_ROOT"

# Stable cache name per query string so different dev profiles do not clobber each other.
QHASH="$(printf '%s' "$QUERY" | openssl dgst -sha256 2>/dev/null | awk '{print $2}' | cut -c1-12)"
if [[ -z "$QHASH" ]]; then
  QHASH="$(printf '%s' "$QUERY" | md5 2>/dev/null | cut -c1-12 || echo default)"
fi
OUT_FILE="$CACHE_ROOT/entry.${QHASH}.map"

if [[ -f "$OUT_FILE" && -z "${METRO_FETCH_FORCE:-}" ]]; then
  echo "metro_dev_fetch_sourcemap: using cache ${OUT_FILE} (METRO_FETCH_FORCE=1 to refresh)" >&2
  echo "$OUT_FILE"
  exit 0
fi

if ! curl -sf --max-time 10 "${BASE}/status" -o /dev/null 2>/dev/null; then
  echo "metro_dev_fetch_sourcemap: Metro may not be reachable at ${BASE} (optional /status check failed)." >&2
fi

echo "metro_dev_fetch_sourcemap: downloading map from ${MAP_URL}" >&2
if ! curl -sf --max-time "${METRO_FETCH_TIMEOUT_SEC:-600}" "$MAP_URL" -o "$OUT_FILE.part"; then
  echo "metro_dev_fetch_sourcemap: failed to download source map. Is Metro up? Tried: ${MAP_URL}" >&2
  echo "metro_dev_fetch_sourcemap: bundle URL for the same query (for copy/paste into stacks): ${BUNDLE_URL}" >&2
  rm -f "$OUT_FILE.part"
  exit 1
fi
mv "$OUT_FILE.part" "$OUT_FILE"
echo "metro_dev_fetch_sourcemap: wrote $OUT_FILE" >&2
echo "$OUT_FILE"
