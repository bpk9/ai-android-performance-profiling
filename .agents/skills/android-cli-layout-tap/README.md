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

Reusable automation lives in **`scripts/android-ui-flows/*.sh`**. New flows start from **`scripts/android-ui-flows/_template_flow.sh`**. Bundled helpers live in **`scripts/`** next to this README (**`layout_find_tap.mjs`**, `layout_stream_tap.sh`, plus tap-run, dump-to-file, label listing, screenshot, and boot-wait scripts — see **SKILLS.md**).

## External links

- [Android CLI overview](https://developer.android.com/tools/agents/android-cli) — `layout`, `screen capture`, emulator commands.
