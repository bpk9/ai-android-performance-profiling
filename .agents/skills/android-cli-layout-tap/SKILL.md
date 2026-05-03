---
name: android-cli-layout-tap
description: >-
  Uses Android CLI `layout` plus `adb shell input tap` to find tap coordinates
  from accessibility metadata and verify taps (e.g. selected tab state). Use when
  driving or testing the Android emulator from the terminal, validating UI
  automation coordinates, pairing `android layout` with adb taps, or when the
  user mentions layout dumps, tap verification, or scripted emulator interaction.
disable-model-invocation: true
---

# Android CLI layout + adb tap

## Prerequisites

- **ADB**: `adb` on `PATH` (e.g. `$ANDROID_SDK_ROOT/platform-tools` or Android Studio SDK).
- **Android CLI**: `android` available ([install](https://developer.android.com/tools/agents/android-cli)); this repo’s workflow often uses `~/bin/android` after installing the official binary.
- **Device serial**: `adb devices`; use `-s <serial>` when more than one device is attached.

Default SDK on this machine is commonly `~/Library/Android/sdk`. Prefer `android info` or `--sdk=…` if the CLI picks the wrong SDK.

## Workflow

1. **Ensure one target emulator** (or pass `--device` / `-s` explicitly):

   ```bash
   adb devices
   ```

2. **Dump layout** as JSON (pretty optional, easier to read):

   ```bash
   android layout --device=emulator-5554 -p
   ```

3. **Pick a node** to tap. Use `content-desc` and/or `text` to find the control. **Tap point** is the `center` field: a string `"[x,y]"` in screen coordinates (parse to integers `x` and `y`).

4. **Send the tap** via adb:

   ```bash
   adb -s emulator-5554 shell input tap <x> <y>
   ```

5. **Verify** with a second layout dump (or screenshot). For tabs/toggles, matching nodes often gain `"state": ["selected"]` after a successful tap.

## Parsing `center` quickly

`center` is always a string like `[1008,2847]`, not separate numbers—strip brackets and split on comma.

Example (stdin = layout JSON):

```bash
android layout --device=emulator-5554 -p | python3 -c "
import json, sys
for n in json.load(sys.stdin):
    cd = n.get('content-desc') or ''
    if 'Explore' in cd and 'Home' not in cd.split(',')[0]:
        print(n.get('center'))
"
```

Adjust the filter for your label; prefer **`content-desc`** for the nav icon row when both icon and text nodes exist (tap the row center from either, but be consistent).

## Optional checks

- **`android screen capture -o /tmp/capture.png`** — visual confirmation after the tap.
- **`adb shell input swipe`** — scroll before dumping layout if the control is off-screen.

## Pitfalls

- **Wrong layer**: Multiple nodes can contain the same word (e.g. body copy vs tab). Prefer the node whose **`content-desc`** or **`bounds`** matches the actual tappable chrome.
- **Stale UI**: Animations or lazy lists may require a short `sleep` before re-running `layout`.
- **Coordinates**: Must match the **current** orientation and resolution; re-dump after rotation.

## References

- [Android CLI overview](https://developer.android.com/tools/agents/android-cli) (`layout`, `screen capture`, `emulator`, `run`).
- Repo emulator setup: `AGENTS.md` → **Local Android emulator**, `docs/android-emulator.md`.
