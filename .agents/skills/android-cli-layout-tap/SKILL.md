---
name: android-cli-layout-tap
description: >-
  Drive Android emulators/devices via Android CLI layout JSON and adb taps; bundled
  layout_find_tap.mjs ($SK scripts). Pair with docs/android-performance-diagnostics for
  jank: Perfetto/gfxinfo localize thread; Metro/Hermes maps map JS to file:line. Token-efficient.
disable-model-invocation: true
---

# Android CLI layout + adb tap

**Read [SKILLS.md](./SKILLS.md)** — path convention (**`SK=.agents/skills/android-cli-layout-tap/scripts`**), **Quick picks**, **Pinpointing exact code**, **Bundled scripts**, **Pitfalls**.

**[README.md](./README.md)** — record → replay flowchart and human-oriented overview.

Non‑negotiables when this skill applies:

1. Prefer existing **`scripts/android-ui-flows/*.sh`** before improvising.
2. Never load full **`android layout -p`** JSON into the chat—pipe through **`layout_find_tap.mjs`** (Node) or use stderr suggestions.
3. After a successful path, record a new flow from **`scripts/android-ui-flows/_template_flow.sh`**.

**Fast path:** **`$SK/layout_cli.sh`** (**tap** / **batch-tap**) or **`$SK/layout_tap_run.sh`**; **`--reuse-layout`** and **`layout_find_tap.mjs --batch-json`** minimize **`android layout`** round-trips. See [SKILLS.md](./SKILLS.md) → **Quick picks**.

**Performance:** Frame drops and **gfxinfo** counts do **not** name TS lines — use **[docs/android-performance-diagnostics.md](../../../docs/android-performance-diagnostics.md)** + Perfetto, then [SKILLS.md](./SKILLS.md) → **Pinpointing exact code** only when **`mqt_js`** / JS is implicated.

**JS → file:line:** **[SKILLS.md](./SKILLS.md) → Agent learnings: JS symbolication** — **Dev:** **`scripts/metro_dev_symbolicate.sh`** / **`metro_dev_fetch_sourcemap.sh`** + **`METRO_BUNDLE_QUERY`**. **Embedded APK (no Metro):** **`ANDROID_BUILD_VARIANT=release`** **`build_android_app.sh`** → **`install_android_app.sh`** → **`app/dist/native-sourcemaps/android/index.android.bundle.map`**; stdin **`index.android.bundle:LINE:COL`**. **`debugOptimized`** may still need Metro in this repo. **Never mix** dev LINE numbers with embedded maps.

**Long list stress tab:** intentional **unvirtualized** harness (`app/(tabs)/longlist.tsx`). Drive **`scripts/android-ui-flows/longlist-scroll-to-end-flow.sh`**, quantify with **`scripts/collect_android_gfxinfo_compare.sh`**, interpret via [SKILLS.md](./SKILLS.md) → **Repo: Long list stress harness**.

**Official Android CLI extras:** [SKILLS.md](./SKILLS.md) → **Google Android CLI agent baseline**, **Annotated screenshot pipeline**.
