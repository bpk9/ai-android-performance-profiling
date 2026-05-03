---
name: sync-profiling-docs
description: >-
  Keeps Android emulator scripts, docs/android-emulator.md, and AGENTS.md in
  sync: defaults, env vars, device-profile order, and links. Use when editing
  scripts/create_android_sim.sh or scripts/open_android_sim.sh, bumping API
  levels or hardware profiles, changing docs/android-emulator.md or the
  emulator section of AGENTS.md, or when the user asks to refresh, reconcile,
  or keep profiling documentation up to date.
disable-model-invocation: true
---

# Sync profiling docs

## When to use

- Any change to `scripts/create_android_sim.sh` or `scripts/open_android_sim.sh`.
- Any change to `docs/android-emulator.md` or the **Local Android emulator** block in `AGENTS.md`.
- User requests: “sync docs,” “update the emulator docs,” “keep docs aligned,” “bump API defaults.”

## Source of truth

1. **Scripts** define runtime behavior (defaults, env names, device-profile fallback order).
2. **`docs/android-emulator.md`** is the human-readable mirror: tables, examples, and workflow must match the scripts.
3. **`AGENTS.md`** only needs the short pointer + links; update if paths or script names change.

Do not let the doc drift ahead of the scripts (no aspirational API levels or flags the scripts do not implement).

## Edit workflow

After changing **either** script:

1. Re-read both scripts end-to-end.
2. Update **`docs/android-emulator.md`**:
   - Default AVD name, API level, hardware-profile strategy (ordered list), ABI behavior.
   - Environment variable names and meanings (create vs open).
   - “Typical flow” commands if script paths or names changed.
   - Examples must use paths that exist (`./scripts/...`).
3. If **`AGENTS.md`** links or script filenames changed, fix the **Local Android emulator** section.
4. **Sanity-check**: defaults in markdown tables match `grep`-able defaults in shell (`AVD_NAME=`, `API_LEVEL=`, profile loop order in `create_android_sim.sh`; `AVD_NAME=` and `exec emulator` in `open_android_sim.sh`).

## API level or device catalog bumps

When raising **`ANDROID_API_LEVEL`** default or changing the **Pixel profile fallback list**:

1. Prefer verifying availability with the user’s SDK: `sdkmanager --list` (or filtered) for `system-images;android-<N>;google_apis;...`.
2. Optionally cross-check [Android SDK platform release notes](https://developer.android.com/tools/releases/platforms) so “latest stable” claims stay accurate.
3. Update the doc **defaults table** and any prose that names a specific Android version.

## Quick verification (agent)

```bash
# Defaults and profile order (adjust paths if repo root differs)
grep -E '^(AVD_NAME|API_LEVEL)|for id in' scripts/create_android_sim.sh
grep '^AVD_NAME=' scripts/open_android_sim.sh
```

Confirm the doc’s table reflects those lines.

## Anti-patterns

- Documenting flags or env vars that only exist in markdown, not in the scripts.
- Changing **`AGENTS.md`** metrics or role text when only emulator tooling changed (touch only the emulator subsection unless the user asked broader edits).
