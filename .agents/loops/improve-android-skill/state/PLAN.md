# PLAN — work queue for the Ralph loop

> Owned by the loop agent. Each iteration: pick the highest-priority unchecked
> item, execute one slice, then tick it off and add follow-ups. New stress
> screens go in the **Stress harness** section; skill work in **Skills**.
> Keep this file short — move done items to `CHANGELOG.md`, not here.

## Now (next iteration should consider)

- [ ] **Verify the loop itself runs end-to-end on this machine.** Check `adb devices` shows `emulator-5554`; run `scripts/android-ui-flows/explore-home-tab-flow.sh` as a smoke test; record observations in `CHANGELOG.md`. *(skill area: foundations)*
- [ ] **Pick the very first quick win.** Skim `.agents/skills/android-cli-layout-tap/SKILLS.md` for any sentence that conflicts with the actual scripts under `.agents/skills/android-cli-layout-tap/scripts/`. Fix one small inconsistency. *(skill area: docs ↔ code drift)*

## Skills (improve the existing family)

### `android-cli-layout-tap` — capture
- [ ] Audit `scripts/android-ui-flows/_template_flow.sh` against the two real flows (`explore-home-tab-flow.sh`, `longlist-scroll-to-end-flow.sh`) — does the template still teach the right pattern? If not, update.
- [ ] Add a tiny `bash "$SK/layout_cli.sh" assert --find "<label>" --state-contains selected` mode (or document the equivalent inline) so flows can declare a postcondition without ad-hoc Node calls.
- [ ] Document the failure mode where `adb` is on PATH but `android` is not, with the exact stderr the user will see.
- [ ] Confirm `layout_find_tap.mjs --batch-json` is exercised by at least one checked-in flow; if not, add the example.

### Android Benchmark (new skill — "runs flows w/ profiling")
- [ ] Write `.agents/skills/android-benchmark/SKILL.md` (+ `SKILLS.md`, `README.md`) following `skill-creator` conventions. Wrap the existing scripts: `collect_android_gfxinfo_compare.sh`, `perfetto_record_android.sh`, `run_perf_comparison_series.sh`. Surface them as a single "run flow + collect this metric set" entry point.
- [ ] Define the **standard metric set** (gfxinfo p50/p90/p99 frame ms, jank %, attached views, RSS, JS thread CPU% from Perfetto, network request count + total bytes). Document which underlying script each comes from.
- [ ] Add Hermes/React DevTools JS CPU profile capture to the benchmark skill (note: `react-native profile-hermes` may be missing — use `hermes-profile-transformer` fallback per `SKILLS.md`).
- [ ] Wire RUM-equivalent counters: long-task count and refresh-rate-min from gfxinfo or Perfetto so a local benchmark mirrors the four short-term Datadog metrics.

### Analyze Benchmark (new skill — "efficiently analyze benchmark")
- [ ] Write `.agents/skills/android-benchmark-analyze/SKILL.md`. Job: take a directory of paired A/B benchmark outputs (master vs fix) and produce a markdown summary with effect size, paired t-test or Mann-Whitney p-value, and a one-line verdict ("ship", "no signal", "regression").
- [ ] Add a "subsystem attribution" cheatsheet: `mqt_js` busy → JS hot path → next step is Hermes profile + matching source map; UI thread spike → measureLayout — measure the tree; RenderThread → overdraw / shadow / large texture.
- [ ] Implement the alternation runner (A/B/A/B/…) explicitly. The current `run_perf_comparison_series.sh` runs in a series — confirm whether it alternates or batches; if batches, add an alternating mode.

### Android Performance (new umbrella skill — orchestrator from the user's diagram)
- [ ] Write `.agents/skills/android-performance/SKILL.md` that points at the three child skills above and `android-cli-layout-tap`, with the four-step flow from the user's notes:
  `1. Capture (if needed)` → `2. Profile 1–3×` → `3. Analyze + identify bottleneck` → `4. Confirm with master vs fix APK alternation`.
- [ ] Add a top-level `bash` entry point (e.g. `scripts/perf/diagnose.sh <flow> <target-metric>`) that runs the four steps in order using the child-skill scripts.

### North-star metrics gap analysis
- [ ] Map each metric in `AGENTS.md` "Key metrics" section to (a) the script that produces it, (b) the parser that aggregates it, (c) the source-map step that links it back to code. List gaps in `CONTEXT.md`.
  - CUJs — likely needs flow-level "user journey" definitions; today we have one flow per tab. Define what a CUJ looks like in this repo.
  - NTBT — derive from gfxinfo + `am start` timing.
  - ART / TRT — need a screen-load instrumentation hook.
  - `@view.long_task_count` — derivable from gfxinfo `>16ms` frame counts or Perfetto JS slices >50ms.
  - `@view.refresh_rate_min` — gfxinfo per-frame stats min FPS over a window.

## Stress harness (grow the test beds — see PROMPT.md guidance #17)

> Every new screen needs: route under `app/app/(tabs)/` (or nested); flow under
> `scripts/android-ui-flows/`; one-paragraph "what failure mode" note in the
> screen file; a baseline benchmark under `.metrics/`. Keep them off the cold-start
> happy path.

- [x] **Unvirtualized list** — `app/app/(tabs)/longlist.tsx` (+ `longlist-scroll-to-end-flow.sh`).
- [ ] **Badly-virtualized FlatList** — same row count as `longlist.tsx`, but with `FlatList`, no `keyExtractor`, no `getItemLayout`, inline arrow `renderItem`, heavy item render, `extraData={Date.now()}`. Goal: jank should differ from `longlist.tsx` in *which* thread is busy, so the analyze skill must distinguish them.
- [ ] **Deep view tree** — a screen that nests `<View>` ~50 levels deep with no perf reason; should spike "attached Views" and `traversal` time without spiking JS.
- [ ] **Large/uncached images** — grid of 100 large remote images via plain `<Image>`; goal: RenderThread + memory pressure.
- [ ] **Heavy JS on render** — `JSON.parse(largeFixture)` in `useMemo([])` deps array that re-runs every render due to a parent state change; goal: `mqt_js` red, frame deadline missed.
- [ ] **Animated without useNativeDriver** — opacity loop on a list of 100 rows; goal: bridge thrash.
- [ ] **Reanimated worklet misuse** — `runOnJS` inside a worklet on every gesture event; goal: looks like UI work but blames JS.
- [ ] **Re-render storms** — global Context whose value is a fresh object every render; consume from 50 children. Goal: massive `mqt_js` time without obvious culprit.
- [ ] **Long task** — a button that triggers a 200ms synchronous loop; goal: `@view.long_task_count` increments.
- [ ] **Bundle bloat** — eager `import * as Foo from 'huge-lib'` at module top; goal: cold-start regression visible in `am start -W` time.
- [ ] **Memory leak** — screen that adds an `AppState` listener on mount but doesn't remove on unmount; loop the screen 20× via flow; meminfo should grow monotonically.
- [ ] **Overdraw** — 8 stacked translucent `<View>`s covering the screen; goal: GPU time visible in Perfetto.
- [ ] **Network waterfall** — sequential `await fetch()` chain of 5 requests on screen mount; should parallelize. Goal: `@view.loading_time` regression.

## Backlog / nice-to-have

- [ ] iOS sibling skill stubs (do not implement until the Android side has stabilized).
- [ ] CI integration: a GitHub Actions job that runs the Android benchmark skill on PR.
- [ ] A `scripts/perf/diff-prs.sh` that picks two PR shas, builds APKs, alternates, and posts the result.
- [ ] Compare `expo-image` vs `<Image>` on the Large/uncached images stress screen as a worked example of the full flow.

## Done (move detail to CHANGELOG.md)

_(empty — first iteration will write the first entry)_
