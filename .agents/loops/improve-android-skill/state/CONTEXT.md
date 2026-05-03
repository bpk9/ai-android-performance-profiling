# CONTEXT — what to investigate next (rolling notes)

> Owned by the loop agent. Short, hint-shaped notes. If something here turns
> into a concrete task, move it to `PLAN.md`. If it turns out to be a
> permanent fact, move it to `LEARNINGS.md`.

## Open questions (no agent has answered yet)

- **Does `scripts/run_perf_comparison_series.sh` alternate (A/B/A/B/…) or batch (A×N then B×N)?** The user explicitly wants alternation to defeat drift. If it batches, either modify it or wrap it. Read the script and check.
- **Which build variant does `scripts/build_android_app.sh` actually produce by default?** The skill says `release` is required for offline benchmarks (no Metro). Confirm the default and whether the install script picks the matching APK automatically.
- **Is `react-native profile-hermes` available in this repo's RN/CLI versions?** `SKILLS.md` warns it is "often missing" — verify on this machine and document the actual fallback in the new Android Benchmark skill.
- **`expo-image` vs `<Image>`** — is `expo-image` already installed? If yes, the Large/uncached images stress screen can A/B them as a worked example.
- **Reanimated version** — what's installed? Worklet patterns vary by major version.

## Repo facts to verify (then promote to LEARNINGS.md if confirmed)

- The "long list" stress harness lists 1200 rows (`LONG_LIST_ROW_COUNT` in `app/(tabs)/longlist.tsx` and `longlist-scroll-to-end-flow.sh` must agree). If you change one, change the other.
- Default emulator serial in this repo is `emulator-5554`. Multi-device runs require explicit `ANDROID_SERIAL`.
- `.metrics/` is gitignored. Use it freely for benchmark artifacts; pick a path scheme that lets a glob pair runs.
- The skill's path convention from repo root is `SK=.agents/skills/android-cli-layout-tap/scripts`.

## Things the user explicitly cares about (re-read before any structural change)

- **Android first**, iOS later, separate skills, possibly reusable bits — do not preemptively abstract.
- **Accuracy > performance** of the *skill itself*. A flaky skill is worse than a slow one.
- **Quick wins first**, deeper work later — but every claim of a perf gain must be backed by alternated A/B benchmarks.
- **Simplicity** — a senior engineer reading the skill should call it obvious.
- **Source maps must always link an issue back to source code.** Dev (Metro) and embedded (release) maps are different files; never cross them.
- **Test on a real simulator before declaring done.**

## Current architecture target (from the user's hand-drawn notes)

```
Android Performance Skill
  uses
    ├── Android CLI Skill         (capture flow as script)         <- already exists as android-cli-layout-tap
    ├── Android Benchmark Skill   (runs flows w/ profiling)         <- to build
    └── Analyze Benchmark Skill   (efficiently analyze benchmark)   <- to build

Flow:
  1. Capture flow (if needed)
  2. Profile 1-3 times to get info
       collect: React Profile, CPU Profile, JS/UI FPS, Network Request Info
  3. Analyze the benchmark & identify bottleneck
  4. Confirm it made it faster by running master branch APK against
     fix branch APK back and forth until statistical significance / confidence
     on target metric (no major regression on other relevant metrics).
```

## Stress harness — what's missing (high level — see PLAN.md for the queue)

We have **one** stress screen (unvirtualized long list). The diagnosis skills
need to distinguish *which* of many failure modes a given symptom maps to. Add
screens that isolate **single** failure modes; do not combine multiple in one.
Ideas (also enumerated in PROMPT.md guidance #17): bad FlatList, deep tree,
uncached images, heavy JS on render, JS-thread animation, worklet misuse,
re-render storms, long tasks, bundle bloat, memory leak, overdraw, network
waterfall.
