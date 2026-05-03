# Android performance diagnostics (root cause + statistics)

This repo’s scripts measure **Expo / React Native on Android** with the same tools Google documents for jank, frames, and memory. Use them together: **summary metrics for A/B and trends**, **traces for cause** (which thread, layout vs JS vs GPU), and **repeated runs** for statistical confidence.

## What to collect (by layer)

| Layer | What it tells you | How (this repo or adb) |
| ----- | ----------------- | ------------------------ |
| **Frame pipeline** | Missed vsync, jank %, frame percentiles (p50 / p90 / p99) | [`scripts/collect_android_gfxinfo_compare.sh`](../scripts/collect_android_gfxinfo_compare.sh) — `adb shell dumpsys gfxinfo <package>`. For per-frame TSV (last ~120 frames): `adb shell dumpsys gfxinfo <package> framestats`. Official overview: [Testing display performance](https://developer.android.com/training/testing/performance) (historical; `framestats` still widely used). |
| **System timeline / jank attribution** | Main vs RenderThread vs SurfaceFlinger; **Android 12+** FrameTimeline jank classes (`AppDeadlineMissed`, buffer stuffing, etc.) | [Perfetto](https://perfetto.dev/docs/) traces — open in [Perfetto UI](https://ui.perfetto.dev). Use [`scripts/perfetto_record_android.sh`](../scripts/perfetto_record_android.sh) (streams trace via `adb exec-out` — avoids writing under `/data/local/tmp` without permission). FrameTimeline data source: [Perfetto FrameTimeline](https://perfetto.dev/docs/data-sources/frametimeline). |
| **RN / Hermes (JS CPU)** | Which JS functions burn time during scroll or navigation | Hermes sampling profiler → convert trace (CLI **`profile-hermes`** may be unavailable — use **hermes-profile-transformer** + map, or **Metro `metro-symbolicate`** for dev bundle line refs). Maps must match the bundle — see [.agents/skills/android-cli-layout-tap/SKILLS.md](../.agents/skills/android-cli-layout-tap/SKILLS.md) **Pinpointing exact code**. Docs: [Debugging release builds](https://reactnative.dev/docs/debugging-release-builds) (source maps), [Profiling](https://reactnative.dev/docs/profiling). |
| **Process memory** | Native / Dalvik / breakdown vs regression | `adb shell dumpsys meminfo <package>` — collected alongside gfxinfo in compare runs. |
| **Macrobenchmark-style metrics** | Startup and scroll **frame timing percentiles** in a repeatable harness | Jetpack [Macrobenchmark](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-metrics) (`FrameTimingMetric`, `frameOverrunMs` on API 31+) — requires a Gradle instrumentation module; best for CI once you add it. |

### Statistical confidence (mobile noise)

Measurements on devices are **non-deterministic** (thermal state, GC, background apps). Common practice:

- Run **many iterations** of the same scripted scenario (Google’s historical guidance often cites **≥10** batches; higher counts tighten confidence — see [Testing display performance](https://developer.android.com/training/testing/performance)).
- Summarize with **percentiles** (p90 / p95 / p99 tails matter for “feel”).
- For comparing **two conditions**, compute a **95% confidence interval for the difference of means** or use formal comparisons — see [Statistically rigorous Android Macrobenchmarks](https://blog.p-y.wtf/statistically-rigorous-android-macrobenchmarks) and Jetpack’s emphasis on distributions in [Macrobenchmark metrics](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-metrics).
- Watch **coefficient of variation** (stdev / mean); very noisy series need more runs or a quieter environment (fixed CPU governor where possible, same build type).

**This repo:** [`scripts/run_perf_comparison_series.sh`](../scripts/run_perf_comparison_series.sh) runs the gfxinfo compare flow **N** times and [`scripts/aggregate_perf_runs.py`](../scripts/aggregate_perf_runs.py) prints **median, mean, stdev, and approximate 95% CI for the mean** on Long-list phase **B** metrics. Increase `ITERATIONS` (e.g. **15–30+**) when comparing two branches.

### Root-cause workflow (recommended)

1. **Quantify** — Run `collect_android_gfxinfo_compare.sh` or a **series** (`run_perf_comparison_series.sh`). Treat **attached view count** and **render node KB** as strong signals for unvirtualized lists; pair with **p90/p99** and **janky %** when frame counts are comparable.
2. **Localize** — Record **Perfetto** while reproducing scroll (`perfetto_record_android.sh`); inspect **UI thread**, **`mqt_js`**, **RenderThread**, and **FrameTimeline** (Android 12+). RN-specific: [Profiling Android UI performance](https://reactnative.dev/docs/profiling) (system trace / Studio capture).
3. **JS layer** — If native trace points at bridge/JS pressure, capture a **Hermes** sampling profile during the same gesture, then symbolicate with a **source map for the same bundle** (dev Metro query vs release `compose-source-maps` output). Step-by-step for agents: **[.agents/skills/android-cli-layout-tap/SKILLS.md](../.agents/skills/android-cli-layout-tap/SKILLS.md) → Pinpointing exact code**. Without a matching map, profiles may only show **bytecode/offset** names, not your `app/**.tsx` lines.
4. **Confirm fix** — Re-run the same **series**; compare CIs / distributions, not single runs.

## Script index

| Script | Role |
| ------ | ---- |
| [`collect_android_gfxinfo_compare.sh`](../scripts/collect_android_gfxinfo_compare.sh) | One-shot A (Home) vs B (Long list + scroll); optional `OUTPUT_DIR` saves `gfxinfo-*.txt` + `meminfo-*.txt`. |
| [`run_perf_comparison_series.sh`](../scripts/run_perf_comparison_series.sh) | Repeat compare **N** times; feeds **aggregate_perf_runs.py**. |
| [`parse_gfxinfo_metrics.py`](../scripts/parse_gfxinfo_metrics.py) | Parse a saved gfxinfo dump to JSON / key=value. |
| [`aggregate_perf_runs.py`](../scripts/aggregate_perf_runs.py) | Table + CI over runs under `run_*`. |
| [`perfetto_record_android.sh`](../scripts/perfetto_record_android.sh) | Record Perfetto trace file for UI analysis. |
| [`metro_dev_fetch_sourcemap.sh`](../scripts/metro_dev_fetch_sourcemap.sh) / [`metro_dev_symbolicate.sh`](../scripts/metro_dev_symbolicate.sh) | Download Metro’s current dev **`entry.map`** and run **`metro-symbolicate`** (stack lines or **`*.cpuprofile`**) — see [SKILLS.md pinpoiting](../.agents/skills/android-cli-layout-tap/SKILLS.md) step 2. |
| [`build_android_app.sh`](../scripts/build_android_app.sh) / [`bundle_android_js_sourcemaps.sh`](../scripts/bundle_android_js_sourcemaps.sh) | **No Metro:** use **`ANDROID_BUILD_VARIANT=release`** build + install for a reliable embedded bundle (this repo); maps under **`app/dist/native-sourcemaps/android/`** — [SKILLS.md — Profiling without Metro](../.agents/skills/android-cli-layout-tap/SKILLS.md#profiling-without-metro-embedded-apk). |

See also: [docs/android-emulator.md](android-emulator.md) (emulator setup + gfxinfo compare intro).
