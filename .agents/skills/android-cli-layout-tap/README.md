# android-cli-layout-tap

Skill for automating the Android emulator from the terminal: dump accessibility layout as JSON, resolve tap coordinates, and send taps with **adb**. Intended for this repo’s **record → replay** UI flows under `scripts/android-ui-flows/`.

## Requirements

- **ADB** on your `PATH` (typically `$ANDROID_SDK_ROOT/platform-tools`).
- **Node.js** (`node` on `PATH`) for **`layout_find_tap.mjs`** — resolves taps from layout JSON (fast path vs piping raw dumps through the model).
- **Android CLI** `android` — [official install](https://developer.android.com/tools/agents/android-cli). This repo often uses `~/bin/android` after installing the binary.
- One target device or emulator; use `adb devices` and `-s <serial>` when multiple devices are connected.

On macOS, the SDK is often `~/Library/Android/sdk`. If the CLI picks the wrong SDK, use `android info` or `--sdk=…`.

## Record → replay flow

How exploration becomes a checked-in bash flow when automating the emulator from an agent:

```mermaid
flowchart TD
    s1["User describes task"]
    s2["Find matching script in scripts/android-ui-flows"]
    s1 --> s2
    s2 --> hasFlow{"Flow script exists?"}
    hasFlow -->|yes| s3a["Run flow; adb devices; then stop"]
    s3a --> done1["Done"]
    hasFlow -->|no| s3b["android screen capture PNG"]
    s3b --> s4["layout → layout_find_tap.mjs → adb tap"]
    s4 --> s5["sleep ~5s; screenshot; check goal with user"]
    s5 --> goalMet{"Desired UI state?"}
    goalMet -->|yes| s6["Record content-desc / text / state for script"]
    s6 --> s7["Copy _template_flow.sh to slug-flow.sh; set POLL_SEC"]
    s7 --> done2["Done"]
    goalMet -->|not yet| uiStuck{"UI unchanged since last tap?"}
    uiStuck -->|yes| s4
    uiStuck -->|no| s5
```

Agent procedure (same flow, with commands and pitfalls): [SKILLS.md](./SKILLS.md).

## What gets checked in

Reusable automation lives in **`scripts/android-ui-flows/*.sh`** (repo root). New flows start from **`scripts/android-ui-flows/_template_flow.sh`**. Tap/layout helpers live under **`.agents/skills/android-cli-layout-tap/scripts/`** — set **`SK`** to that path from the repo root; primary entry is **`layout_cli.sh`** (**tap**, **coords**, **labels**, **dump**, **batch-tap**). Thin wrappers delegate there. **`layout_find_tap.mjs`** supports **`--batch-json`**. Repo-root **`scripts/metro_dev_*.sh`** pair Metro dev maps with **`metro-symbolicate`**; **`scripts/build_android_app.sh`** + **`app/dist/native-sourcemaps/android/*.map`** cover **embedded** APKs — see **SKILLS.md** → **Agent learnings: JS symbolication**. For **jank → thread layer** (gfxinfo / Perfetto), see **`docs/android-performance-diagnostics.md`**.

## External links

- [Android CLI overview](https://developer.android.com/tools/agents/android-cli) — `layout`, `screen capture`, emulator, `docs search`, `init`, `skills`.
- [Android CLI walkthrough (video)](https://www.youtube.com/watch?v=MLDkhDyvTVI) — terminal-first agent workflow, layout vs heavy XML dumps, optional annotate→resolve taps.
