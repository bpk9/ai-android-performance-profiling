#!/usr/bin/env bash
# Build an Android APK for the Expo app in app/.
#
# Expo’s documented primary workflow is:
#   npx expo run:android
# which runs prebuild if needed, compiles with Gradle, installs the binary, and starts Metro.
# See: https://docs.expo.dev/guides/local-app-development/
#
# This script is for splitting **build** from **install** (CI, remote devices, adb over TCP,
# or scripting). It uses the same native output as above: after `expo prebuild`, Gradle drives
# incremental compilation under android/app/build and ~/.gradle (daemon + build cache).
#
# Incremental behavior (important):
# - Prebuild runs only when android/ is missing, or when EXPO_PREBUILD_CLEAN=1, or when
#   EXPO_PREBUILD_SYNC=1 (re-layer app config onto existing native projects without --clean).
# - Repeated runs invoke assemble* only; they do NOT delete outputs unless you pass --clean
#   via Gradle or remove android/ yourself.
# - JavaScript/TypeScript-only changes do not need a native rebuild: use `npx expo start`
#   after the app is installed once (same guidance as Expo docs).
#
# Env:
#   ANDROID_BUILD_VARIANT — debug | debugOptimized | release (default: debugOptimized).
#     Plain debug: ANDROID_BUILD_VARIANT=debug. debugOptimized requires SDK 54+ (see Expo CLI docs).
#   EXPO_PREBUILD_CLEAN — set to 1 to delete and regenerate android/ (full native regen).
#   EXPO_PREBUILD_SYNC — set to 1 to run `expo prebuild -p android` without --clean (sync
#     app config / plugins into existing android/).
#   ANDROID_FULL_CHECKS — set to 1 to run lint/test Gradle tasks (default skips them for speed,
#     matching Expo CLI’s typical Android assemble invocation).
#   ANDROID_GRADLE_EXTRA_ARGS — extra args appended to the ./gradlew line (quoted string).
#   ANDROID_JS_SOURCEMAPS — set to 0 to skip JS bundle + source map generation after Gradle
#     (default: always run scripts/bundle_android_js_sourcemaps.sh). Gradle alone does not emit
#     JS sourcemaps; skipping speeds up builds when you only need the APK.
#
# Prerequisite for development-client workflows: from app/, `npx expo install expo-dev-client`
# then rebuild so native code matches.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/app"

VARIANT="${ANDROID_BUILD_VARIANT:-debugOptimized}"

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -z "$SDK_ROOT" && -d "$HOME/Library/Android/sdk" ]] && SDK_ROOT="$HOME/Library/Android/sdk"
[[ -z "$SDK_ROOT" && -d "$HOME/Android/Sdk" ]] && SDK_ROOT="$HOME/Android/Sdk"
[[ -n "${SDK_ROOT:-}" && -d "$SDK_ROOT" ]] || {
  echo "error: Android SDK not found; set ANDROID_HOME or ANDROID_SDK_ROOT" >&2
  exit 1
}
export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$SDK_ROOT/platform-tools:$SDK_ROOT/emulator:$PATH"

[[ -f "$APP_DIR/package.json" ]] || {
  echo "error: expected Expo app at $APP_DIR" >&2
  exit 1
}

cd "$APP_DIR"

if [[ "${EXPO_PREBUILD_CLEAN:-}" == "1" ]]; then
  CI=1 npx expo prebuild -p android --clean --no-install
elif [[ ! -d android ]]; then
  echo "Generating android/ with expo prebuild..."
  CI=1 npx expo prebuild -p android --no-install
elif [[ "${EXPO_PREBUILD_SYNC:-}" == "1" ]]; then
  echo "Syncing app config into android/ (expo prebuild, no --clean)..."
  CI=1 npx expo prebuild -p android --no-install
fi

cd android

# Match Expo CLI / RN local builds: shared build cache + configure-on-demand; skip lint & test
# for faster dev iteration unless ANDROID_FULL_CHECKS=1.
GRADLE_ARGS=(--build-cache --configure-on-demand)
if [[ "${ANDROID_FULL_CHECKS:-}" != "1" ]]; then
  GRADLE_ARGS+=(-x lint -x test)
fi
if [[ -n "${ANDROID_GRADLE_EXTRA_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  read -r -a _gextra <<< "$ANDROID_GRADLE_EXTRA_ARGS"
  GRADLE_ARGS+=("${_gextra[@]}")
fi

case "$VARIANT" in
  debug)
    ./gradlew "${GRADLE_ARGS[@]}" app:assembleDebug
    echo "APK: $APP_DIR/android/app/build/outputs/apk/debug/app-debug.apk"
    ;;
  debugOptimized)
    ./gradlew "${GRADLE_ARGS[@]}" app:assembleDebugOptimized
    echo "APK: $APP_DIR/android/app/build/outputs/apk/debugOptimized/app-debugOptimized.apk"
    ;;
  release)
    ./gradlew "${GRADLE_ARGS[@]}" app:assembleRelease
    echo "APK: $APP_DIR/android/app/build/outputs/apk/release/app-release.apk"
    ;;
  *)
    echo "error: ANDROID_BUILD_VARIANT must be debug, debugOptimized, or release (got $VARIANT)" >&2
    exit 1
    ;;
esac

if [[ "${ANDROID_JS_SOURCEMAPS:-}" != "0" ]]; then
  echo "Generating JS bundle + source map (expo export:embed)..."
  "$SCRIPT_DIR/bundle_android_js_sourcemaps.sh"
fi
