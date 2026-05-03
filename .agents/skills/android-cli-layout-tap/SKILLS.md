# Android CLI layout + adb tap (agent instructions)

Human-oriented overview, requirements, and the **record → replay** flowchart: [README.md](./README.md).

## Prerequisites

- **ADB**: `adb` on `PATH` (e.g. `$ANDROID_SDK_ROOT/platform-tools` or Android Studio SDK).
- **Android CLI**: `android` available ([install](https://developer.android.com/tools/agents/android-cli)); this repo’s workflow often uses `~/bin/android` after installing the official binary.
- **Node.js** (`node` on `PATH`) for **`layout_find_tap.mjs`** — [nodejs.org](https://nodejs.org/) (LTS is fine; `node -v` to confirm).
- **Device serial**: `adb devices`; use `-s <serial>` when more than one device is attached.

Default SDK on this machine is commonly `~/Library/Android/sdk`. Prefer `android info` or `--sdk=…` if the CLI picks the wrong SDK.

## Agent UI automation flow (record → replay)

**Flowchart (human-readable):** [README.md](./README.md) — section **Record → replay flow**.

Use this sequence whenever the user asks the agent to **drive the emulator** or **automate a UI task**. It keeps exploration reproducible and produces a **checked-in bash flow** when you succeed.

## Low-level tap workflow (reference)

1. **Ensure one target emulator** (or pass `--device` / `-s` explicitly):

   ```bash
   adb devices
   ```

2. **Dump layout** as JSON (pretty optional, easier to read):

   ```bash
   android layout --device=emulator-5554 -p
   ```

3. **Pick a node** to tap. Use `content-desc` and/or `text` to find the control. **Tap point** is the `center` field: a string `"[x,y]"` in screen coordinates (parse to integers `x` and `y`). For repeatable automation, use **`layout_find_tap.mjs`** (see **Bundled scripts**).

4. **Send the tap** via adb:

   ```bash
   adb -s emulator-5554 shell input tap <x> <y>
   ```

5. **Verify** with a second layout dump (or screenshot). For tabs/toggles, matching nodes often gain `"state": ["selected"]` after a successful tap.

## Keep the layout dump out of the model context

**Do not** read a full `android layout` JSON into the chat or paste it for the model to scan. Dumps are large, noisy, and burn context. Prefer:

1. **Pipe** **`android layout … -p`** into **`layout_find_tap.mjs`**, or **`android layout … -p > /tmp/layout.json`** and **`node …/layout_find_tap.mjs -f /tmp/layout.json`** — parse locally with Node, not in the model.
2. Treat **stdout** from the script as the only structured result you need: **`x y`**, **`--json`** (one object), or a **bounded** **`--list`** / **`--list-all-labels`**. Avoid **`cat`** / **`read_file`** on the dump unless debugging outside the agent.
3. When a filter is wrong, use **stderr**: the script prints **ranked “did you mean?”** lines (score, idx, center, desc, text). Retry with **`--find`** or tighter substring filters — still without loading raw JSON into context.

The script parses the full JSON **locally** in one Node process (accurate **`center`** extraction and fuzzy matching). The important optimization is **not** streaming megabytes of JSON through the agent transcript.

## Bundled scripts

Scripts live in **`scripts/`** under this skill directory. In this repo: **`.agents/skills/android-cli-layout-tap/scripts/`** (use that prefix in commands below if you are not already in the `scripts/` directory).

### `layout_find_tap.mjs`

Reads **`android layout -p` JSON** (stdin or **`-f FILE`**), filters nodes, parses **`center`** (`"[x,y]"` string or a two-element array). Prints **`x y`**, **`--json`** output, or an adb line. Implementation: **Node** — in-process JSON parse and **`difflib.SequenceMatcher`-style** fuzzy scoring (same behavior as the historical jq/awk tooling).

**Search**

- **Substring filters**: **`--desc-contains`**, **`--not-desc-contains`**, **`--text-contains`**, **`--state-contains`** (AND).
- **`--find "label"`** — fuzzy match across **`content-desc`**, **`text`**, **`resource-id`**, **`class`** (helps with wording and minor typos). Optional **`--min-score`** (default **0.42**).
- **No match** → stderr lists up to **`--suggest`** candidates (set **`LAYOUT_FIND_TAP_SKIP_SUGGEST=1`** to silence).
- **`--list-all-labels`** — compact index of every tappable node when you do not know the exact string.
- **`--explain`** — stderr line for the chosen node (with **`--find`**).

**Examples** (from the repo root, adjust **`SK`** if you copied the skill elsewhere):

```bash
SK=.agents/skills/android-cli-layout-tap/scripts

# Coordinates from a live dump
android layout --device=emulator-5554 -p \
  | node "$SK/layout_find_tap.mjs" --desc-contains "Explore"

# Emit adb tap line (serial after --adb, or set ANDROID_SERIAL)
android layout --device=emulator-5554 -p \
  | node "$SK/layout_find_tap.mjs" --desc-contains Explore --adb emulator-5554

# Fuzzy label (typos / wording): picks best-scoring node
android layout --device=emulator-5554 -p \
  | node "$SK/layout_find_tap.mjs" --find Explore --explain

# Structured output for tooling / agents (stdout only)
android layout --device=emulator-5554 -p \
  | node "$SK/layout_find_tap.mjs" --find Settings --json

# Dry-run without a device — sample fixture
node "$SK/layout_find_tap.mjs" -f "$SK/fixtures/sample_layout.json" \
  --desc-contains Explore --state-contains selected --list
```

**`layout_stream_tap.sh`** runs **`android layout --device=<serial> -p`** and pipes into **`layout_find_tap.mjs`**:

```bash
SK=.agents/skills/android-cli-layout-tap/scripts
bash "$SK/layout_stream_tap.sh" emulator-5554 --desc-contains Explore --adb emulator-5554
```

**`layout_tap_run.sh`** — same pipe as above, but **`adb shell input tap`** is executed (not only printed; **`--adb`** on **`layout_find_tap.mjs`** only prints a line). Use normal filter flags, not **`--json`** / **`--list`** / **`--adb`**.

```bash
SK=.agents/skills/android-cli-layout-tap/scripts
bash "$SK/layout_tap_run.sh" emulator-5554 --find Explore
```

**`layout_dump_to_file.sh`** — writes pretty layout JSON to a file; **stdout** is the path only (for **`layout_find_tap.mjs -f`** or inspection without flooding the terminal).

```bash
path="$(bash "$SK/layout_dump_to_file.sh" emulator-5554)"
node "$SK/layout_find_tap.mjs" -f "$path" --find Settings --json
```

**`layout_labels.sh`** — **`--list-all-labels`** in one step (discover strings before **`--find`**).

```bash
bash "$SK/layout_labels.sh" emulator-5554
```

**`device_screen_capture.sh`** — PNG via **`android screen capture`** with **`ANDROID_SERIAL`** set; **stdout** is the output path.

```bash
png="$(bash "$SK/device_screen_capture.sh" emulator-5554)"
```

**`wait_boot_completed.sh`** — polls **`sys.boot_completed`** until the device has finished booting.

```bash
bash "$SK/wait_boot_completed.sh" emulator-5554
```

**Filters** (AND logic): **`--desc-contains`**, **`--not-desc-contains`**, **`--text-contains`**, **`--state-contains`** (substring on joined state, e.g. `selected`). With **`--find`**, matches are sorted by score; use **`--nth N`** for the second-best fuzzy hit. **`--list`** prints matches (cap with **`--max-list`**; use **`--compact`**). If stuck, **`--list-all-labels`** then retry **`--find`** with text copied from the row you want.

## Parsing `center` manually

`center` is usually a string like `[1008,2847]`—strip brackets and split on comma. Prefer **`layout_find_tap.mjs`** so filters and **`center`** parsing stay consistent.

Minimal inline example if you cannot run the script:

```bash
android layout --device=emulator-5554 -p | python3 -c "
import json, sys
for n in json.load(sys.stdin):
    cd = n.get('content-desc') or ''
    if 'Explore' in cd:
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
- Repo emulator setup: root **`AGENTS.md`** → **Local Android emulator**, **`docs/android-emulator.md`**.
