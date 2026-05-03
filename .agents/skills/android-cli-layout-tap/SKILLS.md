# Android CLI layout + adb tap (agent instructions)

Human-oriented overview, requirements, and the **record → replay** flowchart: [README.md](./README.md).

**Path convention (this repo):** From the **repository root**, set **`SK=.agents/skills/android-cli-layout-tap/scripts`**. All **`layout_*.sh`**, **`layout_cli.sh`**, and **`layout_find_tap.mjs`** live under **`$SK`**. Reusable **UI flows** (tab → scroll, etc.) live under **`scripts/android-ui-flows/`** at the repo root — not under `$SK`.

## Quick picks

| Goal | What to use |
|------|-------------|
| One tap by fuzzy label (default) | **`bash "$SK/layout_tap_run.sh"`** `<serial>` **`--find`** … — delegates to **`layout_cli.sh tap`** |
| Coordinates / **`--json`** / **`--adb`** line only | **`bash "$SK/layout_cli.sh" coords`** … |
| Discover strings | **`bash "$SK/layout_cli.sh" labels`** … |
| **Multiple taps on the same screen** (one **`android layout`**, one Node parse) | **`bash "$SK/layout_cli.sh" batch-tap`** … **`steps.json`** — or **`"$SK/layout_dump_to_file.sh"`**, then **`node "$SK/layout_find_tap.mjs" -f`** … **`--batch-json`** |
| Tab “unless already selected” | **`bash "$SK/tap_unless_selected.sh"`** (one layout dump per call) |
| Long list tab → fast scroll until last row | **`bash scripts/android-ui-flows/longlist-scroll-to-end-flow.sh`** — fast **`adb`** swipes + **`bash "$SK/layout_cli.sh" coords`** for the last **`List item …`** label; sync row count with `app/(tabs)/longlist.tsx`; env **`MIN_TOWARD_END_SWIPES`** (default **12**) forces visible scrolling when the unvirtualized tree lists every row at once |
| **Long list stress → quantify vs Home (gfx + mem)** | **`bash scripts/collect_android_gfxinfo_compare.sh`** — resets **`gfxinfo`**, idles on **Home**, then runs **`longlist-scroll-to-end-flow.sh`** and prints **B** summaries. Expect **~10–40×** jump in **Total attached Views** and **render node KB** vs **A**; see [Repo: Long list stress harness](#repo-long-list-stress-harness-profiling). |
| **Frames / jank / which subsystem** | **[docs/android-performance-diagnostics.md](../../../docs/android-performance-diagnostics.md)** — **`gfxinfo`** / **`framestats`**, **`scripts/perfetto_record_android.sh`**, series scripts. Shows **missed work**, **not** `longlist.tsx:NN` — pair with **Perfetto thread slices** (`mqt_js` vs UI vs RenderThread). |
| **Fetch Metro map only (no symbolicate)** | **`bash scripts/metro_dev_fetch_sourcemap.sh`** — stdout = cached **`.map`** path (`app/.metro-sourcemap-cache/`). Use when wiring custom tooling; pairing script is **`metro_dev_symbolicate.sh`**. |
| **File:line for hot JS (dev, Metro)** | **`bash scripts/metro_dev_symbolicate.sh`** — fetches **`entry.map`** (predictable **`…/entry.map?`** URL, no multi‑MB bundle download). Pipe **`entry.bundle?…:LINE:COL`** lines or pass **`*.cpuprofile`**. **`METRO_BUNDLE_QUERY`** / host / port must match the device’s bundle URL; **`METRO_FETCH_FORCE=1`** after Metro rebuilds. |
| **Profiling without Metro (APK + embedded Hermes)** | **`ANDROID_BUILD_VARIANT=release`** **`scripts/build_android_app.sh`** → **`install_android_app.sh`** — in **this** Expo/RN project, **`release`** ships **`index.android.bundle`** in the APK so **`scripts/collect_android_gfxinfo_compare.sh`** and UI flows run **without Metro**. Maps: **`bundle_android_js_sourcemaps.sh`** → **`app/dist/native-sourcemaps/android/index.android.bundle.map`**; stdin **`index.android.bundle:LINE:COL`**. **`debugOptimized`** may still show “Unable to load script” / Metro — see [Profiling without Metro](#profiling-without-metro-embedded-apk). |
| **File:line (Hermes bytecode / compose)** | **[Pinpointing exact code](#pinpointing-exact-code-hermes-and-source-maps)** — embedded **`export:embed`** map is often enough for **`metro-symbolicate`**; **full** release bytecode sometimes needs **`compose-source-maps`**. **`gfxinfo` alone cannot name source lines.** |
| Full command surface | **`bash "$SK/layout_cli.sh" help`** |

**Performance:** The slow part is almost always **`android layout`**, not Node. Prefer **one dump** + **`--reuse-layout FILE`**, **`--batch-json`**, or **`batch-tap`** when you need several resolves on the same UI tree.

## Repo: Long list stress harness (profiling)

The **Long list** tab (`app/(tabs)/longlist.tsx`) is a **deliberate** stress screen: **ScrollView** + **one mounted row per index** (not virtualized), **high scroll event rate** (`scrollEventThrottle={1}`) with state updates that **re-render every row**, plus optional **synchronous CPU work per row**. It exists to explode **attached view count** and **UI thread / JS** cost for **gfxinfo**, **meminfo**, **Perfetto**, and automation — **not** as an unknown production regression.

**Identify the issue with this skill + repo scripts**

1. **Reproduce / drive UI** — **`scripts/android-ui-flows/longlist-scroll-to-end-flow.sh`**: **`tap_unless_selected`** on **Long list**, then fast **upward** swipes until **`layout_cli.sh coords --find "List item 1199"`** succeeds (label prefix matches rows like **`List item 1199 · …`**). Keep **`LONG_LIST_ROW_COUNT`** in the flow script aligned with **`LONG_LIST_ROW_COUNT`** in **`longlist.tsx`**.
2. **Quantify vs Home** — **`scripts/collect_android_gfxinfo_compare.sh`**: phase **A** may show **`Total frames rendered: 0`** when idle (percentiles irrelevant); focus on **B** after the scroll flow — **Total attached Views** and **`N views, … render nodes`** usually jump **orders of magnitude** vs **A** (e.g. **~10³–10⁴** views vs **~10²** on Home in typical runs).
3. **Attribute layer** — **`gfxinfo`** proves **how heavy** and **how big the tree is**; it does **not** assign **`longlist.tsx:line`**. For **thread** ( **`mqt_js`** vs **UI** vs **RenderThread** ), use **[docs/android-performance-diagnostics.md](../../../docs/android-performance-diagnostics.md)** and **`scripts/perfetto_record_android.sh`**. For **file:line** on JS, follow **[Pinpointing exact code](#pinpointing-exact-code-hermes-and-source-maps)** after implicating the JS thread.
4. **Statistics** — Noisy devices: **`scripts/run_perf_comparison_series.sh`** + **`scripts/aggregate_perf_runs.py`** (see diagnostics doc).

**Misinterpretation to avoid:** A giant **attached view** count here usually means **virtualization is off** and **all rows are mounted**, not a mysterious native leak elsewhere.

## Prerequisites

- **ADB**: `adb` on `PATH` (e.g. `$ANDROID_SDK_ROOT/platform-tools` or Android Studio SDK).
- **Android CLI**: `android` available ([install](https://developer.android.com/tools/agents/android-cli)); this repo’s workflow often uses `~/bin/android` after installing the official binary.
- **Node.js** (`node` on `PATH`) for **`layout_find_tap.mjs`** — [nodejs.org](https://nodejs.org/) (LTS is fine; `node -v` to confirm).
- **Device serial**: `adb devices`; use `-s <serial>` when more than one device is attached.

Default SDK on this machine is commonly `~/Library/Android/sdk`. Prefer `android info` or `--sdk=…` if the CLI picks the wrong SDK.

## Google Android CLI agent baseline

The official **Android CLI** is designed as a primary agent interface (terminal-first): project/create, emulator control, docs, layout, and screen pipelines live on the same tool surface as in [Android CLI overview](https://developer.android.com/tools/agents/android-cli).

| Goal | Command (typical) |
|------|---------------------|
| Initialize CLI environment / baseline agent hooks | `android init` |
| Discover optional Google “skill” extensions (Compose migration, Navigation 3, Play Billing, …) | `android skills list` |
| Official docs with URLs (prefer over generic web search for API accuracy) | `android docs search <query>` |
| New project from template | `android create <project_name>` (run inside target directory) |
| Deployment targets | Emulator/device listing and control via the CLI’s `list` / emulator commands (see `android --help` on your version) |

Use **`android docs search`** when you need authoritative answers; fetch linked pages with normal tooling instead of pasting huge doc pages into the chat.

## Layout JSON vs legacy UIAutomator dump

- **Prefer** **`android layout -p`** (structured JSON) parsed **locally** by **`layout_find_tap.mjs`** or the bundled shell helpers. Same accessibility metadata (bounds, text, centers) with a pipeline meant for automation.
- **Avoid** treating **`adb shell uiautomator dump`** XML as the primary agent artifact: dumps are verbose, noisy, and expensive in token context. If you must debug XML, keep it in a file and grep locally—do not load full dumps into the model transcript.

This repo’s rule (**never** paste full **`android layout`** JSON into chat) stays in force; the optimization is **local** parsing, not shrinking the wire format alone.

## Annotated screenshot pipeline (optional tap path)

When numbered overlays are easier than fuzzy **`--find`** (dense chrome, unclear strings), the CLI supports a **capture → resolve → adb** loop:

1. **`android screen capture annotate`** — screenshot with numeric markers on clickable elements (exact flags/output paths depend on CLI version; use `android screen capture --help`).
2. Choose the target index **#N** (from the image or any CLI listing).
3. **`android screen resolve <screenshot.png> "tap #N"`** — prints coordinates for **`adb shell input tap x y`**.

**When to use:** exploration, one-off taps, or hierarchy ambiguity. **When not to:** repeatable automation—prefer **`layout_find_tap.mjs`** + **`scripts/android-ui-flows/*.sh`** so flows stay stable across builds. Do not paste large PNGs into the chat; inspect locally or rely on **`resolve`** stdout.

Related bundled helper (plain capture, no annotate): **`device_screen_capture.sh`** — see **Bundled scripts**.

## Fast path for agents (minimal PATH, reliability)

Use this to avoid slow failures (missing **`adb`** / **`node`**, **`EAGAIN`** when piping **`android layout | node`**). **`layout_cli.sh`** and cousins live under **`$SK`** (see **Path convention**).

1. Prefer **`layout_cli.sh`** — single implementation for **`tap`**, **`coords`**, **`labels`**, **`dump`**, **`batch-tap`**. Thin aliases (**`layout_tap_run.sh`**, **`layout_stream_tap.sh`**, **`layout_labels.sh`**, **`layout_dump_to_file.sh`**) call into it so older docs/commands keep working.
2. **`layout_common.sh`** prepends a sane **`PATH`** and resolves **Node** (**`LAYOUT_FIND_TAP_NODE`**, **`NODE_BIN`**, **`PATH`**, **nvm**, Homebrew).
3. **Default:** write layout JSON to a **temp file**, then **`layout_find_tap.mjs -f`** (avoids pipe stalls). **`LAYOUT_TAP_USE_PIPE=1`** restores **`android layout | node`** when you want less disk I/O.
4. **Reuse one dump:** **`layout_cli.sh tap|coords|labels … --reuse-layout /path/to.json`** skips **`android layout`** (you manage freshness). **`layout_dump_to_file.sh`** then multiple **`coords`** calls with **`--reuse-layout`** is the fastest pattern for several lookups on a static screen.
5. **Batch many resolves in one Node process:** **`layout_find_tap.mjs -f dump.json --batch-json steps.json`** — JSON array of objects with keys like **`find`**, **`desc`** (substring on **`content-desc`**), **`text`**, **`state`**, **`nth`**, **`minScore`**, **`explain`**. Stdout: one **`x y`** line per step; with **`--json`**, one JSON array. Shell: **`layout_cli.sh batch-tap`** runs **`adb`** taps for each line (optional **`--sleep`**, env **`LAYOUT_TAP_BATCH_SLEEP`**).
6. **Multi-line automation:** wrap in **`/bin/bash -lc '…'`** or export **`PATH`**; use **`/bin/sleep`** between taps if **`sleep`** is missing.

```bash
SK=.agents/skills/android-cli-layout-tap/scripts
SERIAL="${ANDROID_SERIAL:-emulator-5554}"
bash "$SK/layout_tap_run.sh" "$SERIAL" --find Explore
sleep 1   # or /bin/sleep 1
bash "$SK/layout_tap_run.sh" "$SERIAL" --find Home

# Same screen, one layout dump, two fuzzy resolves + taps (fewer android layout round-trips)
cat > /tmp/steps.json <<'EOF'
[{"find":"Explore"},{"find":"Home"}]
EOF
bash "$SK/layout_cli.sh" batch-tap "$SERIAL" /tmp/steps.json
```

7. **Explicit overrides**: **`LAYOUT_FIND_TAP_NODE`** or **`NODE_BIN`** — absolute path to **`node`**; **`ANDROID_HOME`** — SDK root for **adb** / **android** discovery.

## Pinpointing exact code: Hermes and source maps

**Layering:** **`gfxinfo`** / **aggregates** answer “how bad?” **Perfetto** answers “**which thread / which frame deadline**?” Only **JS profiling + correct source maps** answer “**which `*.tsx` line**?” Native GPU/layout issues never map through Metro — fix the trace first.

| Symptom / metric | Usually points here | Maps to JS file:line? |
|--------------------|----------------------|------------------------|
| High **jank %**, **p99 frame ms**, **Missed Vsync** | Need **timeline** — not enough alone | No |
| **`mqt_js`** busy across vsync ([Profiling](https://reactnative.dev/docs/profiling)) | JS thread — Hermes / bridge | Yes — if you capture profile + **matching** map |
| **UI thread** / **traversal** / **attach Views** spike | Native layout / big hierarchy | Indirectly (which screen mounted) — not a single TS line |
| **RenderThread** / **DrawFrame** | GPU / overdraw / shadows | No — native rendering |
| **Crash / log** stack (`p@1:…`) | Symbolicate with **release** map | Yes — [Debugging release builds](https://reactnative.dev/docs/debugging-release-builds) |

**Frame drops:** Use **`adb shell dumpsys gfxinfo <pkg> framestats`** for per-frame rows, or **Perfetto FrameTimeline** (Android 12+) for *why* a frame missed. Still **no automatic “drop #N → line NN”** — merge **time-aligned** Perfetto + (if JS) Hermes/DevTools.

### Non-negotiables

1. **One bundle, one map** — The map used to symbolicate a profile or stack trace must be the one produced for the **exact** JavaScript bundle that ran on device (same Metro URL query as dev, or same release/EAS build). If the map and binary disagree, “line numbers” will lie. React Native’s own warning: [Notes on source maps](https://reactnative.dev/docs/debugging-release-builds#notes-on-source-maps).
2. **Dev (Metro) vs release (embedded bytecode)** — In **development**, the packager serves the bundle; profiles often reference `index.bundle?...&dev=true&...`. Symbolication must use the **matching** dev/prod and minify flags. The community CLI has had **footguns** when a tool **hardcodes** the wrong map URL — verify the map matches the profile’s bundle query (e.g. [react-native-community/cli#1831](https://github.com/react-native-community/cli/issues/1831)).
3. **Hermes bytecode** — For **release**-style stacks, you often need the **composed** map: Metro packager map + Hermes `hermesc` output, merged with `react-native/scripts/compose-source-maps.js`. Sentry’s walkthrough is the standard reference for the **shape** of that pipeline: [Uploading source maps (Hermes)](https://docs.sentry.io/platforms/react-native/sourcemaps/uploading/hermes/) (same steps help even if you do not use Sentry).
4. **Expo in this repo** — Entry is **`expo-router/entry`** (see `app/package.json` **`main`**). Any `expo export:embed` / doc example that uses `expo/AppEntry.js` must be **swapped** to the real entry for **this** app. Hermes bytecode and OTA: [Using Hermes](https://docs.expo.dev/guides/using-hermes); keep **`runtimeVersion`** aligned when upgrading RN/Hermes.
5. **`profile-hermes` is often absent** — Current **`@react-native-community/cli`** builds may **not** register a **`profile-hermes`** subcommand (even after adding the CLI package). Treat **`react-native profile-hermes`** as **best-effort**: if missing, convert a pulled **`*.cpuprofile`** with **[hermes-profile-transformer](https://github.com/react-native-community/hermes-profile-transformer)** + **`sourceMapPath`**, or rely on **Metro symbolication** below for dev-bundle stacks.

### Recommended order (agents)

1. **Quantify + localize subsystem** — Run **`scripts/collect_android_gfxinfo_compare.sh`** or **`scripts/perfetto_record_android.sh`** (repo root). Read **[docs/android-performance-diagnostics.md](../../../docs/android-performance-diagnostics.md)**. Confirm **`mqt_js`** vs UI vs RenderThread **before** chasing Metro maps.
2. **Dev / Metro symbolication (verified)** — **Prefer the repo script** (downloads **`entry.map`** from Metro without pulling the multi‑MB bundle; cache under **`app/.metro-sourcemap-cache/`**):

   ```bash
   # From repo root; Metro on 8081; default query matches typical Android dev client
   bash scripts/metro_dev_symbolicate.sh <<'EOF'
   http://127.0.0.1:8081/node_modules/expo-router/entry.bundle?platform=android&dev=true&minify=false:LINE:COL
   EOF
   ```

   **`METRO_BUNDLE_QUERY`** (and **`METRO_HOST`** / **`METRO_PORT`**) must match the **`entry.bundle?…`** URL in your stack trace or Hermes profile. **`METRO_FETCH_FORCE=1`** refreshes the cached map after Metro rebuilds.

   **Alternative — Hermes dev profile in one step:** `bash scripts/metro_dev_symbolicate.sh /path/to/profile.cpuprofile` (same **`metro-symbolicate`** feature; map path is injected after fetch).

   Manual fallback (if scripts unavailable): Metro serves **`…/entry.map?`** with the **same query string** as **`…/entry.bundle?`** — **`curl`** the map, then **`cd app && npx metro-symbolicate /path/to/entry.map`**.

   **Sanity check (this repo):** bundle line **196182** → **`app/(tabs)/longlist.tsx:20`** (`StressRow`) when map matches bundle. **`metro-symbolicate`** output may prefix paths oddly (e.g. `http:`); read the **`…/app/…tsx:line`** segment.

3. **Hermes CPU profile** — Dev Menu → Hermes Sampling Profiler → reproduce (same gestures as **`scripts/android-ui-flows/*.sh`** if helpful) → pull **`*.cpuprofile`** → **`bash scripts/metro_dev_symbolicate.sh /path/to/profile.cpuprofile`** **or** **[hermes-profile-transformer](https://github.com/react-native-community/hermes-profile-transformer)** + same map as (2). **`react-native profile-hermes`** is often **missing** from current CLI — do not block on it.
4. **Release / bytecode stacks** — **`metro-symbolicate`** / **`compose-source-maps.js`** per [Debugging release builds](https://reactnative.dev/docs/debugging-release-builds) and [Sentry Hermes pipeline shape](https://docs.sentry.io/platforms/react-native/sourcemaps/uploading/hermes/).

**Gradle:** After prebuild, **`app/android/app/build.gradle`** comments reference **`hermesFlags`** (`-output-source-map`). Release builds should log **Writing sourcemap output** during bundle.

### Profiling without Metro (embedded APK)

Use this when you want **production-like** behavior: **no packager**, Hermes runs **bytecode** shipped in the APK. **Perfetto**, **`gfxinfo`**, **`meminfo`**, and **`scripts/android-ui-flows/*.sh`** are unchanged — only **JS attribution** uses different maps than dev Metro.

| Step | What to do |
|------|------------|
| Build | From repo root: **`ANDROID_BUILD_VARIANT=release`** **`bash scripts/build_android_app.sh`**. Outputs **`app/android/app/build/outputs/apk/release/app-release.apk`**. **Prefer `release` here:** React Native **debuggable** variants often **skip or omit** a usable on-device JS bundle; **`debugOptimized`** was observed on emulator with RedBox **“Unable to load script … Metro”** — layout automation and **`collect_android_gfxinfo_compare.sh`** then fail (`tap_unless_selected` / **Home** never match). **`release`** embeds Hermes + assets; use it for **offline profiling** until Gradle **`react { debuggableVariants … }`** is adjusted for embedded bundles on other variants. |
| Install | **`ANDROID_BUILD_VARIANT=release`** **`bash scripts/install_android_app.sh`** (must match the APK you built). |
| JS maps for this repo | After each build, **`scripts/bundle_android_js_sourcemaps.sh`** runs unless **`ANDROID_JS_SOURCEMAPS=0`**. Artifacts: **`app/dist/native-sourcemaps/android/index.android.bundle`** + **`index.android.bundle.map`**. Use that **`.map`** with **`cd app && npx metro-symbolicate dist/native-sourcemaps/android/index.android.bundle.map`** and stdin stack lines / **`*.cpuprofile`**. Frames usually look like **`index.android.bundle:LINE:COL`** (copy **exactly** from log/profile — full filesystem paths often yield **`null:null:null`** if **`LINE:COL`** does not match the generated bundle). |
| Hermes bytecode | For **release** profiles or minified stacks, you may still need **`react-native/scripts/compose-source-maps.js`** (Metro map + Hermes compiler map) per [Debugging release builds](https://reactnative.dev/docs/debugging-release-builds) and [Hermes source maps](https://docs.sentry.io/platforms/react-native/sourcemaps/uploading/hermes/). **`bundle_android_js_sourcemaps.sh`** generates the **Metro** side (`--unstable-transform-profile hermes`); Gradle may emit additional Hermes map files under **`app/android/app/build`** — merge when **`metro-symbolicate`** alone does not resolve `*.tsx` lines. |
| Match discipline | The map must belong to the **same build** as the installed APK. Rebuild and reinstall after TS/JS changes; do not symboliclate with an old map. |

**Why not Metro:** Useful for **cold start**, **real minification**, **no USB reverse / port 8081**, CI-installed APKs, or avoiding dev-only overhead. Tradeoff: slower iteration (full native rebuild when native deps change; JS-only changes still need a new bundle embedded via rebuild or your workflow’s bundle step).

**Worked example (this repo, embedded `export:embed` map — LINE/COL change every rebuild):**

```bash
cd app
# Screen component:
echo 'index.android.bundle:1429:100' | npx metro-symbolicate dist/native-sourcemaps/android/index.android.bundle.map
# → /app/(tabs)/longlist.tsx:32:LongListScreen

# Same generated line, hotter column → per-row stress path:
echo 'index.android.bundle:1429:500' | npx metro-symbolicate dist/native-sourcemaps/android/index.android.bundle.map
# → /app/(tabs)/longlist.tsx:20:StressRow   # confirms CPU work + list harness in maps
```

### Agent learnings: JS symbolication

Lessons from **running** this repo’s scripts on device — use so agents don’t confuse layers or waste time on **`null:null:null`** symbolication.

| Topic | Takeaway |
|-------|----------|
| **Metrics vs maps** | **`gfxinfo`**, **layout automation**, and **Perfetto** tell you **how bad** and **which thread**; they do **not** print **`app/(tabs)/foo.tsx:NN`**. You still need a **stack line**, **Hermes profile frame**, or **Metro URL:line** plus the **matching map**. Reading **`*.tsx`** in the repo explains code — it is **not** the same as proving a hot frame via source maps. |
| **Two bundles, two maps** | **Dev Metro** (`entry.bundle?…` from packager) and **embedded** (`index.android.bundle` from **`expo export:embed`**) are **different generated files**. **LINE** numbers are **not interchangeable** across them (e.g. dev sanity **~196182** vs embedded **~1429** for similar sources — illustrative only; rebuilds change numbers). |
| **stdin shape for `metro-symbolicate`** | **Dev:** paste the **full** URL prefix from the stack, ending with **`:LINE:COL`** — e.g. **`http://127.0.0.1:8081/node_modules/expo-router/entry.bundle?platform=android&dev=true&minify=false:LINE:COL`**. **Embedded:** frames usually look like **`index.android.bundle:LINE:COL`** — use that short form; **absolute disk paths** to the bundle file often produce **`null:null:null`** even when the map is correct, because the parser expects the **same string shape as the runtime frame**. |
| **`null:null:null`** | Wrong **map for build**, wrong **LINE/COL**, or **column 0** on a generated line where mappings need a **non-zero column** — fix by copying **LINE** and **COL** from the **actual** RedBox / log / **`*.cpuprofile`** frame, not by guessing from **`wc -l`**. |
| **Odd stdout prefix** | **`metro-symbolicate`** may emit **`http:/`** before a path — still read **`…/app/(tabs)/….tsx:line:symbol`**. |
| **`metro_dev_*` scripts** | **`metro_dev_fetch_sourcemap.sh`** hits **`…/entry.map?`** directly (no full bundle download). **`metro_dev_symbolicate.sh`** runs symbolication from **`app/`** with **`npx metro-symbolicate`**. **`METRO_DEV_SOURCE_MAP=/path/to/map`** skips fetch. |
| **Embedded APK build variant (this repo)** | **`ANDROID_BUILD_VARIANT=release`** verified: **`collect_android_gfxinfo_compare.sh`** + **`longlist-scroll-to-end-flow.sh`** run **without Metro**; phase **B** shows **~10×+** attached views vs Home and symbolication hits **`longlist.tsx`** (**`StressRow`** / **`LongListScreen`**). **`debugOptimized`** + install **without Metro** showed RedBox / missing bundle — **do not** assume all **`build_android_app.sh`** variants embed JS; match variant to “offline APK” intent. |

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

1. **Pipe** **`android layout … -p`** into **`layout_find_tap.mjs`**, or use **`layout_dump_to_file.sh`** / **`layout_tap_run.sh`** (temp file under the hood) — parse locally with Node, not in the model.
2. Treat **stdout** from the script as the only structured result you need: **`x y`**, **`--json`** (one object), or a **bounded** **`--list`** / **`--list-all-labels`**. Avoid **`cat`** / **`read_file`** on the dump unless debugging outside the agent.
3. When a filter is wrong, use **stderr**: the script prints **ranked “did you mean?”** lines (score, idx, center, desc, text). Retry with **`--find`** or tighter substring filters — still without loading raw JSON into context.

The script parses the full JSON **locally** in one Node process (accurate **`center`** extraction and fuzzy matching). The important optimization is **not** streaming megabytes of JSON through the agent transcript.

## Bundled scripts

Scripts live in **`scripts/`** under this skill directory. In this repo: **`.agents/skills/android-cli-layout-tap/scripts/`** (use that prefix in commands below if you are not already in the `scripts/` directory).

### `layout_cli.sh`

Unified entry ( **`tap`**, **`coords`**, **`labels`**, **`dump`**, **`batch-tap`** ). Handles temp-file vs pipe (**`LAYOUT_TAP_USE_PIPE`**), **`--reuse-layout`**, and **`PATH`** / Node bootstrap via **`layout_common.sh`**. Prefer calling this directly; wrapper scripts are thin **`exec`** forwards.

```bash
SK=.agents/skills/android-cli-layout-tap/scripts
bash "$SK/layout_cli.sh" tap emulator-5554 --find Explore
bash "$SK/layout_cli.sh" coords emulator-5554 --find Settings --json
path="$(bash "$SK/layout_cli.sh" dump emulator-5554)"
bash "$SK/layout_cli.sh" coords emulator-5554 --reuse-layout "$path" --find Home --json
bash "$SK/layout_cli.sh" batch-tap emulator-5554 ./steps.json --sleep 0.4
```

### `layout_common.sh`

Sourced by the tap helpers (not run alone). **`layout_common_prepend_path`** fixes **`PATH`** for **`adb`** / **`android`**. **`layout_common_require_node`** sets **`LAYOUT_FIND_TAP_NODE_CMD`** from **`LAYOUT_FIND_TAP_NODE`**, **`NODE_BIN`**, **`PATH`**, **nvm**, or common install locations.

### `layout_find_tap.mjs`

Reads **`android layout -p` JSON** (stdin or **`-f FILE`**), filters nodes, parses **`center`** (`"[x,y]"` string or a two-element array). Prints **`x y`**, **`--json`** output, or an adb line. Implementation: **Node** — **one** JSON parse per invocation; **`--batch-json`** reuses the parsed tree for multiple match passes (fast multi-tap on the same dump).

**Search**

- **Substring filters**: **`--desc-contains`**, **`--not-desc-contains`**, **`--text-contains`**, **`--state-contains`** (AND).
- **`--find "label"`** — fuzzy match across **`content-desc`**, **`text`**, **`resource-id`**, **`class`** (helps with wording and minor typos). Optional **`--min-score`** (default **0.42**).
- **`--batch-json FILE`** — **`FILE`** may be **`-`** for stdin. Requires **`-f LAYOUT.json`** for the hierarchy (cannot mix layout stdin with batch stdin). Batch steps are a JSON array of objects with optional keys **`find`**, **`minScore`**, **`desc`**, **`ndesc`**, **`text`**, **`state`**, **`nth`**, **`explain`** (same semantics as the CLI flags). Incompatible with global **`--find`** / filter flags / **`--list`** / **`--adb`**.
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

**`layout_stream_tap.sh`** — alias for **`layout_cli.sh coords`**. **Default:** temp layout file + **`-f`**. **`LAYOUT_TAP_USE_PIPE=1`** restores **`android layout | node`**.

```bash
SK=.agents/skills/android-cli-layout-tap/scripts
bash "$SK/layout_stream_tap.sh" emulator-5554 --desc-contains Explore --adb emulator-5554
```

**`layout_tap_run.sh`** — alias for **`layout_cli.sh tap`**. Resolves coordinates then runs **`adb shell input tap`**. Supports **`--reuse-layout FILE`**. Use normal filter flags for tap mode, not **`--json`** / **`--list`** / **`--adb`**.

```bash
SK=.agents/skills/android-cli-layout-tap/scripts
bash "$SK/layout_tap_run.sh" emulator-5554 --find Explore
```

**`tap_unless_selected.sh`** — one **`android layout`** dump, then Node **`--find`** + **`--state-contains`** probe; if no match, tap **`--find`** only. Avoids redundant tab taps when already selected. See **Idempotent navigation**.

```bash
bash "$SK/tap_unless_selected.sh" emulator-5554 Explore
LAYOUT_TAP_VERBOSE=1 bash "$SK/tap_unless_selected.sh" emulator-5554 Home
```

**`layout_dump_to_file.sh`** — writes layout JSON to a file (sources **`layout_common.sh`** for **`PATH`** only); **stdout** is the path only (for **`layout_find_tap.mjs -f`** or inspection without flooding the terminal).

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

## Fixtures vs live layout (saving “known screens”)

**Live automation** should still drive taps from a **current** **`android layout`** on the target device. Bounds and **`center`** depend on resolution, orientation, font scale, and app version—reusing an old JSON file as the source of **`adb input tap`** coordinates across sessions will eventually miss.

**Do reuse one dump within the same session** when the UI is unchanged: **`--reuse-layout`**, **`--batch-json`**, **`layout_cli.sh batch-tap`** (see **Quick picks**). That saves **`android layout`** round-trips, not long-term “memory.”

**Saved layout JSON is appropriate for:**

- **Offline checks** of **`layout_find_tap.mjs`** (e.g. **`fixtures/sample_layout.json`**).
- **CI / regression** on a **pinned** emulator profile (fixed density and resolution), comparing structure or key nodes—not blindly replaying stored **`center`** values on new builds without validation.

**Reducing screenshots:** Prefer **layout assertions** when accessibility exposes enough signal: **`layout_cli.sh coords`** with **`--find`**, **`--desc-contains`**, **`resource-id`** via filters, or **`--state-contains`** (“right tab selected”, etc.). Use PNG capture when you need **pixels**, branding, or what the hierarchy does not expose.

## Idempotent navigation (e.g. “already on Explore”)

**What happens today if you repeat a tap on the current tab?** The flow still sends **`adb shell input tap`** at the tab’s **center**. Often that is harmless (no navigation change). In real apps it may not be: some patterns treat a second tap as **scroll-to-top**, **refresh**, or **re-select** a nested section—behavior varies by product.

**Guard without new APIs:** After a fresh layout dump, the tab’s accessibility node usually includes **`state`** with **`selected`** (see **`--state-contains`**). Before tapping, check whether a node matching the tab label already has that state; only tap if it does not.

Bundled helper:

```bash
SK=.agents/skills/android-cli-layout-tap/scripts
bash "$SK/tap_unless_selected.sh" emulator-5554 Explore   # optional third arg: state substring, default selected
bash "$SK/tap_unless_selected.sh" emulator-5554 Home
```

Equivalent inline logic (same as the helper): one dump to a temp file; if **`layout_find_tap.mjs -f … --find LABEL --state-contains selected`** exits **0**, skip; else **`layout_find_tap.mjs -f … --find LABEL`** then **`adb`** tap.

**Production-style extensions** (beyond fuzzy **`--find`** on short strings):

- **Stable selectors**: Prefer **`resource-id`** / testIDs exposed in the hierarchy; combine **`--desc-contains`** / **`--text-contains`** with **`--not-desc-contains`** so you do not match body copy.
- **State variety**: Some chrome uses **`checked`** instead of **`selected`**; pass a third argument to **`tap_unless_selected.sh`** or use **`--state-contains`** accordingly.
- **Intents / deep links**: Where supported, **`adb shell am start …`** with a route can land on a screen without depending on tab order or animations—often the most reliable “production” automation for multi-tab shells.
- **Explicit postconditions**: After actions, assert layout (e.g. title **`--find`**, or **`--state-contains selected`** on the expected tab) or screenshot diff in CI—not only “we tapped.”
- **Layered runners**: For large apps, dedicated UI-test frameworks (Espresso, Maestro, Detox, Appium) maintain selectors and synchronization; the CLI layout pipeline stays useful for quick agent-driven probes and thin flows.

## Pitfalls

- **Wrong `scripts/` path** — Tap helpers are **`$SK/*.sh`** (see **Path convention** at top), **not** `scripts/layout_tap_run.sh` at repo root. Only **android-ui-flows** live under **`scripts/android-ui-flows/`**.
- **Embedded symbolication format** — Piping a **filesystem path** to **`index.android.bundle`** into **`metro-symbolicate`** often fails; use the **short frame text** **`index.android.bundle:LINE:COL`** as logs show. See **[Agent learnings: JS symbolication](#agent-learnings-js-symbolication)**.
- **Profiling APK vs Metro** — **`ANDROID_BUILD_VARIANT=release`** install for **embedded-bundle** benchmarks and flows. **`debugOptimized`** (and typical debuggable builds) may **require Metro** on device; RedBox breaks **`tap_unless_selected`** / tab labels. See **[Profiling without Metro](#profiling-without-metro-embedded-apk)**.
- **Wrong source map**: Treating Hermes or profiler output as “exact file:line” **without** verifying map ↔ bundle ↔ build — wrong attribution is worse than none. See **[Pinpointing exact code](#pinpointing-exact-code-hermes-and-source-maps)**.
- **Wrong layer**: Multiple nodes can contain the same word (e.g. body copy vs tab). Prefer the node whose **`content-desc`** or **`bounds`** matches the actual tappable chrome.
- **Stale UI**: Animations or lazy lists may require a short `sleep` before re-running `layout`.
- **Coordinates**: Must match the **current** orientation and resolution; re-dump after rotation.
- **Thin PATH**: If **`adb`**, **`bash`**, or **`sleep`** “not found”, prepend **`/usr/bin:/bin`** to **`PATH`**, use absolute paths, or run **`layout_tap_run.sh`** (bundled helpers bootstrap **`PATH`** and **Node**).
- **Pipe stalls**: If **`android layout | node …`** errors with **`EAGAIN`** / read failures, use **`layout_tap_run.sh`** / **`layout_dump_to_file.sh`** (temp file path) instead of piping; or set **`LAYOUT_TAP_USE_PIPE=0`** (default) on the bundled helpers.
- **Extra layouts**: Running several **`layout_tap_run`** calls in a row on the **same** screen repeats expensive **`android layout`** work—use **`--reuse-layout`**, **`--batch-json`**, or **`layout_cli.sh batch-tap`** instead.
- **Archived layout files**: Do not treat a checked-in or saved **`android layout`** dump as the permanent source of tap coordinates for real devices—see **Fixtures vs live layout**.

## References

- [Android CLI overview](https://developer.android.com/tools/agents/android-cli) (`layout`, `screen capture`, `emulator`, `run`, `docs`, `init`, `skills`).
- Introductory walkthrough (CLI layout, annotate/resolve, agent workflow): [YouTube — Android CLI / agent tooling](https://www.youtube.com/watch?v=MLDkhDyvTVI).
- Repo emulator setup: root **`AGENTS.md`** → **Local Android emulator**, **`docs/android-emulator.md`**.
- React Native: [Profiling](https://reactnative.dev/docs/profiling) (threads / jank story), [Debugging release builds](https://reactnative.dev/docs/debugging-release-builds) (source maps).
- Expo: [Using Hermes](https://docs.expo.dev/guides/using-hermes).
- Repo: **[docs/android-performance-diagnostics.md](../../../docs/android-performance-diagnostics.md)** (gfxinfo, Perfetto, statistics).
