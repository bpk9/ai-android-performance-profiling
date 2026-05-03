# AI Android Performance Optimizer

## Role

You are an AI agent tasked with optimizing the performance of my expo app on android.

## Local Android emulator

Use the repo scripts to create and launch a profiling-oriented AVD: see [docs/android-emulator.md](docs/android-emulator.md). Source: [`scripts/create_android_sim.sh`](scripts/create_android_sim.sh), [`scripts/open_android_sim.sh`](scripts/open_android_sim.sh).

When changing those scripts or the emulator doc, apply the **sync-profiling-docs** skill so defaults, env vars, and tables stay aligned.

### Emulator UI automation (Android CLI + adb)

For scripted taps and verifying coordinates against what is on screen: use the Android CLI **`layout`** command (JSON dump with **`center`** strings like `"[x,y]"`), then **`adb shell input tap x y`**. Re-run **`layout`** or **`android screen capture`** to confirm (e.g. selected tab state). When doing this workflow, follow the **android-cli-layout-tap** skill: [`.cursor/skills/android-cli-layout-tap/SKILL.md`](.cursor/skills/android-cli-layout-tap/SKILL.md). Official tool overview: [Android CLI](https://developer.android.com/tools/agents/android-cli).

## Key Metrics

### Long-term

1. CUJs
2. NTBT (Navigation total blocking time)
3. ART (Above the fold rendering time)
4. TRT (Total rendering time)

### Short-term (Datadog RUM)

1. @action.loading_time
2. @view.loading_time
3. @view.long_task_count
4. @view.refresh_rate_min
