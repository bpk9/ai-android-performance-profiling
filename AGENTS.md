# AI Android Performance Optimizer

## Role

You are an AI agent helping optimize the performance of an **Expo** app on **Android**.

## Goal

Improve measurable app and navigation performance on Android (emulator and real devices) using this repo’s tooling, scripts, and observability—without scope creep into unrelated product features.

## Behavioral guidelines

Guidelines to reduce common LLM coding mistakes. Use together with the project-specific sections below (especially **Success criteria**).

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them—don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity first

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it—don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that **your** changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-driven execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Success criteria

- Changes are **evidence-led** (profiles, RUM, traces, or reproducible steps)—not guesswork.
- **Emulator and script defaults** in [docs/android-emulator.md](docs/android-emulator.md) and this file **match** `scripts/create_android_sim.sh` and `scripts/open_android_sim.sh` after any edit (defaults, env var names, profile order, links).
- **Instruction files** stay scannable: headings, short bullets, links to real paths.
- Skills tracked in the **Skills** table stay accurate—all live under [`.agents/skills/`](.agents/skills/) (see **Skills** below).

## Documentation

**Default bias:** when you change code or scripts, **update the local docs** they depend on (`docs/`, this file, script headers) in the same change.

- **Emulator / profiling** — After editing the Android emulator scripts or [docs/android-emulator.md](docs/android-emulator.md), reconcile defaults and links with the shell sources (grep `AVD_NAME`, `API_LEVEL`, device `for id in` loop, etc.).
- **Rules and prompts** — Keep goal, constraints, and reference material easy to scan (labeled sections, tables where helpful).

## Skills

| Skill | Use when | Manifest |
| ----- | -------- | -------- |
| **skill-creator** | Creating or refining Agent Skills, evals, or description/trigger tuning. | [`.agents/skills/skill-creator/SKILL.md`](.agents/skills/skill-creator/SKILL.md) |
| **vercel-react-native-skills** | React Native / Expo: lists, animations, navigation, rendering, native modules, mobile performance. | [`.agents/skills/vercel-react-native-skills/SKILL.md`](.agents/skills/vercel-react-native-skills/SKILL.md) |
| **android-cli-layout-tap** | Emulator UI: discover **`scripts/android-ui-flows/`**, `layout` → **`layout_find_tap.mjs`** → tap; record flows from **`_template_flow.sh`**. | [`.agents/skills/android-cli-layout-tap/SKILL.md`](.agents/skills/android-cli-layout-tap/SKILL.md) (agents: [`SKILLS.md`](.agents/skills/android-cli-layout-tap/SKILLS.md), humans: [`README.md`](.agents/skills/android-cli-layout-tap/README.md)) |

Install or upgrade via [Skills CLI](https://skills.sh) (`npx skills add …`, `npx skills update`) or [`scripts/upgrade_npx_skills.sh`](scripts/upgrade_npx_skills.sh). **Convention:** keep all skills for this repo under [`.agents/skills/`](.agents/skills/) (including custom manifests added by hand).

**Autonomous loops** that *improve* the skills above live under [`.agents/loops/`](.agents/loops/). Today: [`improve-android-skill`](.agents/loops/improve-android-skill/README.md) — Ralph-style 30-min iterations of `claude -p` that grow the Android performance skill family **and** the in-app stress harness those skills target. State (PLAN/CONTEXT/CHANGELOG/LEARNINGS) is checked in; iteration logs are gitignored.

## Local Android emulator

Create and open a profiling-oriented AVD with [`scripts/create_android_sim.sh`](scripts/create_android_sim.sh) and [`scripts/open_android_sim.sh`](scripts/open_android_sim.sh). Full detail: [docs/android-emulator.md](docs/android-emulator.md) (includes **`dumpsys gfxinfo`** / **`meminfo`** comparison via [`scripts/collect_android_gfxinfo_compare.sh`](scripts/collect_android_gfxinfo_compare.sh)). Profiling stack, statistics, and Perfetto: [docs/android-performance-diagnostics.md](docs/android-performance-diagnostics.md). When you change those scripts or the doc, keep **Documentation** (above) and the doc tables aligned with the scripts.

### Emulator UI automation (Android CLI + adb)

For scripted taps: Android CLI **`layout`** (JSON, **`center`** as `"[x,y]"`) → **`adb shell input tap x y`**. Re-check with **`layout`** or **`android screen capture`**.

**Record → replay:** Before improvising, look for **`scripts/android-ui-flows/*.sh`** (reusable flows). If none fit, follow the **Agent UI automation flow** in **android-cli-layout-tap** (screenshot → **`layout_find_tap.mjs`** → poll ~**5s** → save a new flow from **`scripts/android-ui-flows/_template_flow.sh`**). Agent detail: [`.agents/skills/android-cli-layout-tap/SKILLS.md`](.agents/skills/android-cli-layout-tap/SKILLS.md); overview: [`.agents/skills/android-cli-layout-tap/README.md`](.agents/skills/android-cli-layout-tap/README.md). [Android CLI](https://developer.android.com/tools/agents/android-cli).

## Key metrics (reference)

### Long-term

| Acronym | Meaning |
| ------- | ------- |
| CUJs | Critical user journeys |
| NTBT | Navigation total blocking time |
| ART | Above-the-fold rendering time |
| TRT | Total rendering time |

### Short-term (Datadog RUM)

1. `@action.loading_time`
2. `@view.loading_time`
3. `@view.long_task_count`
4. `@view.refresh_rate_min`
