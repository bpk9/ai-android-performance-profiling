# CHANGELOG — append-only per-iteration log

> Newest at the top. Each entry: iteration number, UTC timestamp, branch,
> what changed (file paths), why, what was verified on the simulator,
> any benchmark numbers (with N), and any follow-ups added to PLAN.md.
>
> Keep entries short. Detail goes in commit messages.

## Format

```
## iter NN — YYYY-MM-DD HH:MM:SS UTC — branch ralph/improve-android-skill

**Picked from PLAN.md:** <short title>
**Why:** <one sentence>
**Changed:** <file paths>
**Verified on simulator:** <yes/no, what flow>
**Benchmark (if perf-claim):** target=<metric> N=<paired samples> baseline=<x> after=<y> p~=<p> verdict=<ship|nosignal|regression>
**Added to PLAN.md:** <one-line follow-ups, or "none">
**Notes:** <optional>
```

## Entries

_(none yet — iter 01 will write the first entry)_
