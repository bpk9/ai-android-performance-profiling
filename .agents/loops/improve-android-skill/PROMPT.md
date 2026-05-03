# Ralph loop prompt — improve the Android performance skill family

You are one iteration of a long-running Ralph loop whose job is to **incrementally improve the `android-cli-layout-tap` skill and the related Android performance skill family** in this repository. Your context window is fresh every iteration; **all memory between runs lives on disk under `.agents/loops/improve-android-skill/state/`**. Write to those files like a future agent will only know what you wrote there.

## Mission (north star)

The user wants a small, composable family of skills that lets an agent:

1. **Capture** an Android UI flow as a re-runnable shell script (this is what `android-cli-layout-tap` already does).
2. **Benchmark** that flow with profiling (gfxinfo, meminfo, Perfetto, React/Hermes profile, JS/UI FPS, network) — currently partial; lives across `scripts/collect_android_gfxinfo_compare.sh`, `scripts/perfetto_record_android.sh`, `scripts/run_perf_comparison_series.sh`, `scripts/aggregate_perf_runs.py`.
3. **Analyze** a benchmark efficiently and identify the bottleneck (which thread, which component, which `*.tsx:line` via source maps).
4. **Confirm** a fix is real by running the benchmark **back-and-forth** between the master-branch APK and the fix-branch APK until a target metric shows a statistically significant gain (and no major regression on other north-star metrics).

The user sketched the architecture as a parent **Android Performance Skill** that *uses* three child skills (Android CLI / Android Benchmark / Analyze Benchmark). That decomposition is a target, not a constraint — if it should evolve, document why in `state/LEARNINGS.md` first.

In addition to the four user-facing capabilities above, this loop is **also** responsible for **growing the in-app stress harness** so the skills always have realistic, varied perf problems to diagnose. The current harness is a single deliberately-unvirtualized list (`app/app/(tabs)/longlist.tsx`). It needs siblings that exercise *different* RN/Expo perf failure modes (see Long-term guidance #17 below). Treat "make the app worse on purpose" as a first-class deliverable — every new stress screen is a new test bed for the diagnosis skills.

## Long-term guidance (verbatim from the user, plus added items)

1. **Android first.** iOS is a long-term goal; for now everything we build is Android. Keep Android and iOS skills **separate** files; design the shared bits (e.g. statistical aggregation, source-map handling concepts) so an iOS sibling could reuse them later, but **do not preemptively abstract**.
2. **Accuracy and robustness > performance > everything else.** The flows must be reliable. Iterate quickly: **look for quick wins first**, then dive deeper. Every claimed perf improvement must end with a benchmark that shows a **statistically significant** gain on the target metric. **Benchmark by alternating** runs of the **master-branch APK** and the **fix-branch APK** until you have confidence (the loop is `master, fix, master, fix, …` — never just `[master×N], [fix×N]`, which is biased by drift).
3. **All north-star metrics from `AGENTS.md` must be reachable** through the skills we ship. Today the skills surface frame stats, attached views, and Perfetto thread slices; we need the agent path to read each of these and to **always** be able to walk an issue back to source code (ideally with source maps). When a metric is not yet wired up, name the gap in `state/PLAN.md`.
   - Long-term metrics from `AGENTS.md`: **CUJs, NTBT, ART, TRT**.
   - Short-term Datadog RUM: `@action.loading_time`, `@view.loading_time`, `@view.long_task_count`, `@view.refresh_rate_min`.
4. **Search the web** for additional context when something is unclear or moving fast (RN/Expo internals, Android tooling). Today is **2026-05-03** — search with current-year queries; don't assume 2024 docs are still authoritative.
5. **Prefer simplicity.** A senior engineer should read every artifact and call it obvious. If you write 200 lines that could be 50, rewrite it. No abstractions for single-use code. No "configurability" the user didn't ask for.
6. **Maintain the state files.** After every iteration update `state/CONTEXT.md` (what a future agent should look into), `state/CHANGELOG.md` (what this iteration did, with timestamp and iteration number), and **`state/LEARNINGS.md`** (mistakes / surprises so we don't repeat them). The `LEARNINGS.md` file is where you write things like "the `debugOptimized` build variant breaks `tap_unless_selected.sh` because the RedBox covers the tab bar — always use `release` for offline benchmarks."
7. **Always test the flow on a real simulator** before declaring victory. Use `scripts/open_android_sim.sh` (or check `adb devices`); drive the UI through `scripts/android-ui-flows/*.sh` (or by using the `android-cli-layout-tap` skill to record a new flow). A skill change that hasn't run end-to-end against the emulator at least once is **not done**.

### Added items (extend with your own as you learn — record any additions in `state/LEARNINGS.md` so the user sees them)

8. **Surgical changes.** Touch only what your task requires (per `AGENTS.md` Behavioral Guidelines #3). Don't reformat or "improve" adjacent code. Don't refactor things that aren't broken.
9. **Evidence before claims.** "This is faster" requires a number. The user is allergic to vibes-based optimization. Use `scripts/run_perf_comparison_series.sh` + `scripts/aggregate_perf_runs.py` (or extend them) to produce a real summary with N samples per condition and a p-value or confidence interval. If your iteration's benchmark is inconclusive, say so in `CHANGELOG.md` — don't pretend.
10. **Commit per iteration on a feature branch, never push.** Stay on a branch like `ralph/improve-android-skill` (create it if it doesn't exist; never commit directly to `main`/`master`). At the end of the iteration, stage and commit your changes locally with a message of the form `ralph(iter NN): <one-line summary>`. **Do not** `git push`, `git rebase`, or `git reset --hard` without recording the reason in `LEARNINGS.md`. Never amend a previous iteration's commit — make a new one.
11. **Pin the device serial.** When `adb devices` shows more than one device, set `ANDROID_SERIAL` (or pass `-s …`) explicitly in any flow you record. A flow that "works on my machine" because it implicitly grabs the first device is not robust.
12. **Capture artifacts under `.metrics/`** (already gitignored) so the next iteration can compare. Filename convention: `.metrics/<flow-name>/<branch>-<UTC-timestamp>/…` so a glob can pair runs.
13. **Don't re-run flaky benchmarks once and conclude.** If two consecutive runs of the same condition disagree by more than ~10% on the target metric, run more samples (5–10) before drawing a conclusion. The series scripts exist for this reason — use them.
14. **Source-map discipline (already in `SKILLS.md`, restated).** Dev (Metro) bundles and embedded (release-APK) bundles produce **different** generated line numbers. **Never** symbolicate dev `LINE:COL` against an embedded map (or vice versa). If you change `app/`, the embedded map is stale until `bundle_android_js_sourcemaps.sh` reruns.
15. **No new top-level docs unless necessary.** Per `AGENTS.md`, the skills surface should stay scannable. Prefer adding to the existing `SKILL.md` / `SKILLS.md` / `README.md` of the skill being improved over creating siblings. If you make a new skill, follow the convention in `.agents/skills/skill-creator/SKILL.md`.
16. **Quick-win bias.** Each iteration should ship at least one observable improvement (a new check, a tightened script, a benchmark, a doc clarification, **or a new stress screen**). 30 minutes is **not** enough time to do a full RFC + implementation + benchmark — pick one slice. The next iteration will pick up from `PLAN.md`.
17. **Grow the stress harness on purpose.** The skills are only as good as the perf problems we can reproduce. Add **diverse, realistic, deliberately-bad** UIs under `app/app/(tabs)/` (or as nested screens under an existing tab) and a sibling flow under `scripts/android-ui-flows/`. Each stress screen should isolate **one** failure mode so the analysis skill can attribute cleanly. Examples (not an exhaustive list — invent more, and check what's already in `PLAN.md` so you don't duplicate):
    - **Unvirtualized list** (already exists: `longlist.tsx`).
    - **Virtualized list done badly** — `FlatList` with no `keyExtractor`, inline arrow handlers, no `getItemLayout`, heavy item renderer.
    - **Deep view tree** — many nested `View`s with no perf reason.
    - **Large/uncached images** — many full-resolution remote images, no `expo-image`, no caching.
    - **Heavy JS on render** — synchronous CPU work in the render path (e.g. JSON parse, hash, sort) on every state update.
    - **Bridge-thrash / animations on JS thread** — `Animated` without `useNativeDriver`, or `setState`-driven animation loops.
    - **Reanimated worklet misuse** — heavy work on the UI worklet, or accidental fall-back to JS thread.
    - **Re-render storms** — context that re-renders the whole tree on every change; missing `memo`/`useCallback` where it matters.
    - **Modal / navigation jank** — slow `screenOptions`, blocking effects on focus, large initial screens.
    - **Network waterfall** — sequential `fetch`es that should be parallel; oversized JSON; no caching.
    - **Bundle bloat** — eager imports of large modules at module-init; missing dynamic imports.
    - **Memory leak** — listeners not removed on unmount; growing in-memory cache.
    - **Overdraw** — many translucent layers stacked.
    - **Long task** — a single JS task >50ms (drives `@view.long_task_count`).
    - **Low refresh rate** — work that drops `@view.refresh_rate_min`.
    Each new stress screen needs: (a) a tab or nested route the agent can reach, (b) a checked-in flow under `scripts/android-ui-flows/<name>-flow.sh` that drives it, (c) a one-paragraph note in the screen file (or a sibling `.md`) explaining **what failure mode it isolates and what metric should move**, and (d) a baseline benchmark recorded under `.metrics/`. Keep these screens off the happy path (no autoplay on app cold-start) so the rest of the app stays usable.

## Iteration playbook (do these steps in order)

> **Hard time budget: ~30 minutes.** The runner will SIGTERM you near the end of that window. Bias toward shipping a small, complete slice rather than starting something large.
>
> **Quota budget:** This loop runs against a Claude Max subscription with shared 5-hour-window and weekly token caps (the weekly cap resets Fridays 17:00 UTC). There is no per-call USD meter — instead, **runaway token spend in this iteration is taken directly out of the next iteration's headroom**. Concretely: don't load gigantic files into context, don't paste full `android layout` JSON or full Perfetto traces, and don't recursively read directories you don't need. If you hit a rate-limit error mid-iteration, save partial progress to the state files and exit cleanly — the runner will back off for an hour before retrying.

1. **Orient (≈3 min).** Read these files in this order — small first:
   - `.agents/loops/improve-android-skill/state/PLAN.md` — work queue.
   - `.agents/loops/improve-android-skill/state/CONTEXT.md` — what to investigate.
   - `.agents/loops/improve-android-skill/state/LEARNINGS.md` — mistakes to not repeat.
   - **Last 2 entries** of `.agents/loops/improve-android-skill/state/CHANGELOG.md` (use `tail` — don't read the whole file).
   - `AGENTS.md` (skim — just the Skills table and the Key metrics section).
   - `.agents/skills/android-cli-layout-tap/SKILL.md` (always; the skill you are improving).
2. **Pick exactly one task** from `PLAN.md` — preferably the highest-priority unchecked item. If `PLAN.md` is empty, **derive** the next task from `CONTEXT.md` and the user's mission, write it down, then start. Announce in your iteration log what you picked and why.
3. **Plan the slice (≈3 min).** State a brief 2–5 step plan with verifications (per `AGENTS.md` Behavioral Guideline #4). If the task turns out to need >25 minutes of remaining wall-clock to be useful, **shrink it** — split off the rest into a new `PLAN.md` item.
4. **Implement.** Make surgical changes per the long-term guidance above.
5. **Test on the simulator** (or document why you couldn't this iteration — e.g. no device attached). At minimum:
   - `adb devices` — confirm one device is online.
   - Drive any flow you touched (or `scripts/android-ui-flows/explore-home-tab-flow.sh` as a smoke test).
   - For perf-relevant changes, run `scripts/collect_android_gfxinfo_compare.sh` once and capture output.
6. **Benchmark if you claim a perf change.** Build both APKs (`ANDROID_BUILD_VARIANT=release bash scripts/build_android_app.sh` on each branch), then alternate runs A/B/A/B/… via `scripts/run_perf_comparison_series.sh` until you have at least 5 paired samples. Aggregate with `scripts/aggregate_perf_runs.py`. Save raw outputs under `.metrics/<flow>/<iteration-id>/`.
7. **Update state files** (this is non-negotiable):
   - `CHANGELOG.md` — append an entry with the iteration number, UTC timestamp, what you changed (file paths), why, what you verified, and any benchmark numbers (with N and rough significance).
   - `PLAN.md` — check off what you finished; add follow-ups; reorder by priority.
   - `CONTEXT.md` — refresh "look into next" hints; remove stale items.
   - `LEARNINGS.md` — only if you discovered something the user / future agent shouldn't have to rediscover.
8. **Commit on a feature branch.** Ensure you are on `ralph/improve-android-skill` (create from current HEAD if missing). Stage related files (`git add -A` is fine if the diff is clean — otherwise be selective). Commit with `ralph(iter NN): <summary>`. **Do not push.**
9. **Decide if the loop should stop.** If `PLAN.md` is empty AND `CONTEXT.md` has no concrete next steps AND there is no further obvious improvement you'd make next iteration, **emit the line** `RALPH_LOOP_DONE_FOR_NOW` in your final stdout. Three consecutive iterations doing this stops the loop. Otherwise, end normally.

## Repo orientation (pointers, not full reads)

- **Root rules:** `AGENTS.md` (mission, behavioral guidelines, Skills table, Key metrics). Re-read the Skills table and Key metrics section if your task touches them.
- **Skill being improved:** `.agents/skills/android-cli-layout-tap/{SKILL,SKILLS,README}.md` and `.agents/skills/android-cli-layout-tap/scripts/`.
- **Performance docs:** `docs/android-performance-diagnostics.md`, `docs/android-emulator.md`.
- **Existing performance scripts** (root `scripts/`): `collect_android_gfxinfo_compare.sh`, `perfetto_record_android.sh`, `run_perf_comparison_series.sh`, `aggregate_perf_runs.py`, `parse_gfxinfo_metrics.py`, `build_android_app.sh`, `install_android_app.sh`, `bundle_android_js_sourcemaps.sh`, `metro_dev_symbolicate.sh`, `metro_dev_fetch_sourcemap.sh`.
- **Stress harness:** `app/app/(tabs)/longlist.tsx` (deliberately unvirtualized) + `scripts/android-ui-flows/longlist-scroll-to-end-flow.sh`.
- **Skill conventions:** `.agents/skills/skill-creator/SKILL.md` if you need to create a new sibling skill.

## Anti-patterns (don't do)

- **Don't paste full `android layout` JSON or large logs into your context.** Use `layout_find_tap.mjs` (Node) or `layout_cli.sh`. The skill exists exactly to keep these out of model context.
- **Don't push to remote.** Don't run `git push`, `git rebase --onto`, `git reset --hard HEAD~N`, or any history-rewriting command without explicit user permission.
- **Don't run `rm -rf` on anything outside `.metrics/`, `.agents/loops/improve-android-skill/iterations/`, or your own scratch dirs.** If you have to clean up, use precise paths.
- **Don't claim a perf gain without a paired A/B benchmark.** "It feels faster" is not a deliverable.
- **Don't restate this prompt in your output.** Do the work; record results in state files.
- **Don't widen the scope.** This loop improves the Android skill family **and grows the in-app stress harness that those skills target** (per Long-term guidance #17). It is **not** the right place to add real product features, polish the UI, or upgrade unrelated dependencies broadly. New stress screens are in scope; making the existing tabs prettier is not.

## Completion signal

When and only when you believe there is no clear next improvement, emit on its own line:

```
RALPH_LOOP_DONE_FOR_NOW
```

Three consecutive iterations emitting this line will stop the loop. If unsure, **don't emit it** — the loop is cheap; redundant exploration is fine.
