#!/usr/bin/env bash
# Produce a Metro JS bundle + JavaScript source map for the Android app (upload to Datadog, Sentry, etc.).
#
# Gradle (build_android_app.sh) does not emit JS sourcemaps; this script does. It runs automatically
# after every build_android_app.sh unless ANDROID_JS_SOURCEMAPS=0. You can also run this script
# alone. Dev installs still load JS from Metro; these artifacts are for symbolicated release-style
# stacks and upload to tools like Datadog or Sentry.
#
# Output (default, gitignored via app/dist/): dist/native-sourcemaps/android/
#   index.android.bundle
#   index.android.bundle.map
#
# Hermes release binaries often need an extra compose step (Metro map + hermesc map → one .map).
# See your error SDK docs (e.g. Sentry Expo advanced sourcemaps). This script generates the Metro
# bundle and primary source map from expo export:embed.
#
# Env:
#   ANDROID_JS_SOURCEMAP_DIR — override output directory (absolute or relative to app/).
#   ANDROID_EXPORT_EMBED_EXTRA — extra argv passed to expo export:embed (space-separated).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/app"

OUT="${ANDROID_JS_SOURCEMAP_DIR:-dist/native-sourcemaps/android}"
if [[ "$OUT" != /* ]]; then
  OUT="$APP_DIR/$OUT"
fi

mkdir -p "$OUT/assets"

cd "$APP_DIR"

EMBED_CMD=(
  npx expo export:embed
  --platform android
  --entry-file node_modules/expo-router/entry.js
  --dev false
  --bundle-output "$OUT/index.android.bundle"
  --sourcemap-output "$OUT/index.android.bundle.map"
  --assets-dest "$OUT/assets"
  --unstable-transform-profile hermes
)

if [[ -n "${ANDROID_EXPORT_EMBED_EXTRA:-}" ]]; then
  # shellcheck disable=SC2206
  read -r -a _extra <<< "$ANDROID_EXPORT_EMBED_EXTRA"
  EMBED_CMD+=("${_extra[@]}")
fi

"${EMBED_CMD[@]}"

echo "JS bundle: $OUT/index.android.bundle"
echo "Source map: $OUT/index.android.bundle.map"
