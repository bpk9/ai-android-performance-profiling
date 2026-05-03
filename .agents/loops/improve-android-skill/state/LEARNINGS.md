# LEARNINGS — never repeat these mistakes

> Append-only. Each entry: a fact, a footgun, or a constraint that a future
> agent should know **before** starting work. If something turns out to be
> wrong later, do **not** delete it — strike it through and add the
> correction with a date.
>
> Source the fact: "verified by running X on YYYY-MM-DD" beats "I think".

## Seeded from `.agents/skills/android-cli-layout-tap/SKILLS.md`

- **Two bundles, two maps.** Dev (Metro) `entry.bundle?…` and embedded (release APK) `index.android.bundle` are different generated files. **LINE numbers do not transfer.** Always use the map for the same build that produced the stack frame. Cross-mapping yields `null:null:null` or worse — confidently wrong file:line. (`.agents/skills/android-cli-layout-tap/SKILLS.md` → "Agent learnings: JS symbolication".)
- **`debugOptimized` build variant breaks layout automation.** RedBox "Unable to load script … Metro" covers the tab bar, so `tap_unless_selected.sh` and any `--find "Home"` flow fail silently. Use `ANDROID_BUILD_VARIANT=release` for offline benchmarks.
- **Stale layout coordinates.** Saved `android layout` JSON should never be the source of `adb input tap` coordinates across sessions — bounds depend on resolution, orientation, font scale, and app version. Reuse a dump only within one session via `--reuse-layout` / `--batch-json`.
- **Pipe stalls.** `android layout | node …` can EAGAIN. Default in the bundled scripts is temp-file + `-f`; only set `LAYOUT_TAP_USE_PIPE=1` when you have a reason.
- **Embedded symbolicate frame format.** Pipe `index.android.bundle:LINE:COL` (the literal log shape) — passing a filesystem path to the bundle file usually returns `null:null:null`.

## Loop hygiene

- The Ralph loop itself lives at `.agents/loops/improve-android-skill/`. Iteration logs in `iterations/` are gitignored. State files (`PLAN.md`, `CONTEXT.md`, `CHANGELOG.md`, `LEARNINGS.md`) are checked in; commit them with each iteration's other changes.
- The loop runs `claude -p --dangerously-skip-permissions` with `--max-budget-usd` and a wall-clock cap. **Do not** add interactive prompts to scripts the loop calls — they will hang the whole iteration until the wall-clock kill.

## Repo facts (verify before promoting from CONTEXT.md)

_(empty — promote from CONTEXT.md as facts are confirmed)_
