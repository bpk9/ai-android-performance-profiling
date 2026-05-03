# Local Android emulator

Scripts under [`scripts/`](../scripts/) provision and launch a dedicated Android Virtual Device (AVD) for profiling an Expo app so measurements focus on app behavior rather than constantly rebuilding emulator definitions by hand.

## Prerequisites

- Android SDK installed (Android Studio or command-line tools only).
- **SDK command-line tools** in `android_sdk/cmdline-tools/.../bin` (`avdmanager`, `sdkmanager`).
- **Emulator** and **platform-tools** packages (the create script asks `sdkmanager` to install them with the system image if needed).
- `ANDROID_HOME` or `ANDROID_SDK_ROOT` set, or the default SDK path present (`~/Library/Android/sdk` on macOS, `~/Android/Sdk` on Linux).

If `sdkmanager` prints warnings about SDK XML version mismatch, update the **Android SDK Command-line Tools** in Android Studio (SDK Manager → SDK Tools) so Studio and CLI tools stay aligned.

## [`scripts/create_android_sim.sh`](../scripts/create_android_sim.sh)

Creates an AVD **only if one with the same name does not already exist** (idempotent: exits successfully when the AVD is already there).

### Defaults

| Setting | Default | Notes |
|--------|---------|--------|
| AVD name | `ExpoPerf` | Same default as `open_android_sim.sh`. |
| API level | `36` | Android 16 Google APIs image. |
| Hardware profile | Auto | Picks the first available: `pixel_10_pro_xl` → `pixel_10_pro` → `pixel_9_pro_xl` → `pixel_9_pro`, else `pixel_9`. Flagship profiles reduce the chance that low default RAM/skin limits skew profiling. |
| ABI | Host-based | `arm64-v8a` on Apple Silicon / ARM64; `x86_64` otherwise. Override with `ANDROID_ABI_OVERRIDE`. |

### Environment variables

| Variable | Purpose |
|----------|---------|
| `ANDROID_AVD_NAME` | AVD name (default `ExpoPerf`). |
| `ANDROID_API_LEVEL` | API level for the system image (default `36`). |
| `ANDROID_DEVICE_PROFILE` | `avdmanager -d` device id (optional; if unset, auto-selection above runs). |
| `ANDROID_ABI_OVERRIDE` | Force ABI segment of the system image package (optional). |
| `ANDROID_HOME` / `ANDROID_SDK_ROOT` | SDK root. |

### Example

```bash
./scripts/create_android_sim.sh
ANDROID_AVD_NAME=MyPerf ./scripts/create_android_sim.sh
```

## [`scripts/open_android_sim.sh`](../scripts/open_android_sim.sh)

Starts the emulator for the same AVD name (`ANDROID_AVD_NAME`, default `ExpoPerf`). **Fails with exit code 1** if that AVD does not exist (run the create script first).

Extra arguments are passed through to `emulator`, for example:

```bash
./scripts/open_android_sim.sh -no-snapshot
```

## Typical flow

1. Create (once per machine, or after deleting the AVD):

   ```bash
   ./scripts/create_android_sim.sh
   ```

2. Open the simulator:

   ```bash
   ./scripts/open_android_sim.sh
   ```

3. Run the Expo / React Native Android build against the running device (for example `npm run android` or `npx expo run:android`).

Use the same `ANDROID_AVD_NAME` in both steps if you override it.

## Frame stats and memory (gfxinfo compare)

To capture **device-side rendering stats** and contrast a light screen with the **Long list** unvirtualized scroll harness:

1. Start the app on the emulator or device (`ANDROID_SERIAL` if not `emulator-5554`).
2. Run:

   ```bash
   ./scripts/collect_android_gfxinfo_compare.sh
   ```

The script resets **`dumpsys gfxinfo`** counters, stays idle on **Home** for a few seconds (baseline), prints trimmed metrics plus a **`meminfo` TOTAL** line, resets again, runs **`scripts/android-ui-flows/longlist-scroll-to-end-flow.sh`**, then prints the same extracts.

**How to read the drop:** after **B**, expect **`Total attached Views`** (and the **`N views, … kB of render nodes`** line from gfxinfo) to be **much larger** than baseline **A** — that reflects mounting the full unvirtualized list. **`meminfo` TOTAL** PSS/RSS typically increases as well. **Janky frame %** can fluctuate with how many frames were rendered since the reset; use similar dwell times or repeat runs if you need to compare jank directly.

Optional env: **`ANDROID_PACKAGE`**, **`OUTPUT_DIR`** (saves full **`dumpsys gfxinfo`** + **`meminfo`** per phase under that directory), **`BASELINE_IDLE_SEC`**.

**Deeper diagnosis (Perfetto, Hermes, statistics):** [android-performance-diagnostics.md](android-performance-diagnostics.md) — root-cause layers, confidence intervals, and scripts (`run_perf_comparison_series.sh`, `perfetto_record_android.sh`).

## Keeping this doc accurate

After editing the scripts or defaults here, re-read `scripts/create_android_sim.sh` and `scripts/open_android_sim.sh` and update this file and [AGENTS.md](../AGENTS.md) so tables, env vars, and links stay consistent with the shell sources.
