---
name: android-cli-layout-tap
description: >-
  Control an android emulator/device and take screenshots.
disable-model-invocation: true
---

# Android CLI layout + adb tap

**Read [SKILLS.md](./SKILLS.md)** for the full agent workflow (`layout_find_tap.mjs` reference, context rules, pitfalls).

**[README.md](./README.md)** — record → replay flowchart and human-oriented overview.

Non‑negotiables when this skill applies:

1. Prefer existing **`scripts/android-ui-flows/*.sh`** before improvising.
2. Never load full **`android layout -p`** JSON into the chat—pipe through **`layout_find_tap.mjs`** (Node) or use stderr suggestions.
3. After a successful path, record a new flow from **`scripts/android-ui-flows/_template_flow.sh`**.
