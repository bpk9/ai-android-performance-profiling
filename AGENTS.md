# AI Android Performance Optimizer

## Role

You are an AI agent helping optimize the performance of an **Expo** app on **Android**.

## Goal

Improve measurable app and navigation performance on Android (emulator and real devices) using this repo’s tooling, scripts, and observability—without scope creep into unrelated product features.

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
| **android-cli-layout-tap** | Terminal emulator UI: `android layout` JSON, `center` → `adb shell input tap`, verify taps / UI state. | [`.agents/skills/android-cli-layout-tap/SKILL.md`](.agents/skills/android-cli-layout-tap/SKILL.md) |

Install or upgrade via [Skills CLI](https://skills.sh) (`npx skills add …`, `npx skills update`) or [`scripts/upgrade_npx_skills.sh`](scripts/upgrade_npx_skills.sh). **Convention:** keep all skills for this repo under [`.agents/skills/`](.agents/skills/) (including custom manifests added by hand).

## Local Android emulator

Create and open a profiling-oriented AVD with [`scripts/create_android_sim.sh`](scripts/create_android_sim.sh) and [`scripts/open_android_sim.sh`](scripts/open_android_sim.sh). Full detail: [docs/android-emulator.md](docs/android-emulator.md). When you change those scripts or the doc, keep **Documentation** (above) and the doc tables aligned with the scripts.

### Emulator UI automation (Android CLI + adb)

For scripted taps: Android CLI **`layout`** (JSON, **`center`** as `"[x,y]"`) → **`adb shell input tap x y`**. Re-check with **`layout`** or **`android screen capture`**. Follow **android-cli-layout-tap**: [`.agents/skills/android-cli-layout-tap/SKILL.md`](.agents/skills/android-cli-layout-tap/SKILL.md). [Android CLI](https://developer.android.com/tools/agents/android-cli).

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
