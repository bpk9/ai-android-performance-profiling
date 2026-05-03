# Ralph loop — improve the Android performance skill family

A **Ralph loop** ([Geoffrey Huntley's pattern][ralph]) that runs `claude -p` in
30-minute iterations to improve the [`android-cli-layout-tap`](../../skills/android-cli-layout-tap/SKILL.md)
skill and grow its sibling skills (Android Benchmark, Analyze Benchmark, Android
Performance umbrella). It also **deliberately makes the app worse** in varied
ways — every new stress screen is a new test bed for the diagnosis skills.

Each iteration:

1. Reads `state/{PLAN,CONTEXT,LEARNINGS}.md` (and the last 2 entries of `CHANGELOG.md`).
2. Picks one task from `PLAN.md`.
3. Plans, implements, tests on the emulator.
4. Updates the state files and commits to `ralph/improve-android-skill` (no push).

Memory between iterations lives **only** in those state files — the model
context is fresh each run, which is the point of the pattern.

[ralph]: https://ghuntley.com/loop/

## Layout

```
.agents/loops/improve-android-skill/
├── README.md          (this file)
├── PROMPT.md          read by the agent every iteration; long-term guidance + playbook
├── run.sh             the loop runner
├── .gitignore         ignores iterations/
├── state/             checked in — bridges memory between iterations
│   ├── PLAN.md
│   ├── CONTEXT.md
│   ├── CHANGELOG.md
│   └── LEARNINGS.md
└── iterations/        gitignored; per-iteration claude stdout/stderr
    ├── loop.log
    └── iter-NNNN-YYYYMMDD-HHMMSS.log
```

## Quick start

```bash
# from the repo root
bash .agents/loops/improve-android-skill/run.sh
```

Defaults:

| Knob                            | Default | Meaning |
| ------------------------------- | ------: | ------- |
| `RALPH_INTERVAL_SEC`            |    1800 | wall-clock seconds between iteration **starts** (30 min) |
| `RALPH_MAX_ITERATIONS`          |     100 | hard upper bound on iterations |
| `RALPH_PER_ITER_TIME_LIMIT_SEC` |    1740 | per-iteration wall-clock kill (29 min, leaves 60s buffer) |
| `RALPH_COMPLETION_SIGNAL`       | `RALPH_LOOP_DONE_FOR_NOW` | agent emits this line when it has nothing left to do |
| `RALPH_COMPLETION_THRESHOLD`    |       3 | consecutive signals required to stop |
| `RALPH_MODEL`                   |  unset  | optional `--model` override (Sonnet stretches Max quota much further than Opus) |
| `RALPH_DRY_RUN`                 |       0 | `1` skips the actual `claude` call (wiring test) |
| `RALPH_PER_ITER_BUDGET_USD`     |  unset  | passed to `claude --max-budget-usd` only if set (no-op on Max — see below) |
| `RALPH_RATE_LIMIT_BACKOFF_SEC`  |    3600 | sleep this long after a fast-fail iteration that looks rate-limited |
| `RALPH_RATE_LIMIT_FAST_FAIL_SEC`|      60 | iter exits faster than this AND non-zero → candidate for rate-limit backoff |
| `RALPH_RATE_LIMIT_PATTERN`      | `rate.?limit\|usage limit\|429\|quota\|too many requests\|reset.*in` | case-insensitive regex grepped against the iteration log to confirm |

The runner honors `Ctrl-C`: it finishes the current iteration's cleanup and exits.

### Cost & quota — which knobs actually matter

Depends on how `claude` is authenticated:

- **Claude Max subscription (default for this repo's user).** `--max-budget-usd` is a **no-op** — it only meters pay-as-you-go API spend. The real limits are the **5-hour rolling window** (~88k tokens on Max 5×, ~220k on Max 20×) and a **weekly cap** that resets **Fridays 17:00 UTC**. All models share that pool — Sonnet stretches it much further than Opus, so `RALPH_MODEL=claude-4.5-sonnet` (or whatever the current Sonnet slug is) is a sensible default for long unattended runs. When you blow a window cap, `claude` exits non-zero with a 429 / "rate limit" message; the runner detects that pattern and sleeps for `RALPH_RATE_LIMIT_BACKOFF_SEC` (default 1 hour) instead of charging into the next iteration and burning the rest of your weekly quota on retries. Plan long runs so the loop straddles the Friday reset, or schedule them to start just after it.
- **Pay-as-you-go API key (`ANTHROPIC_API_KEY` set).** Set `RALPH_PER_ITER_BUDGET_USD=3` (or whatever you're comfortable with) and the runner will pass `--max-budget-usd` for a hard per-iteration USD cap.

The wall-clock cap (`RALPH_PER_ITER_TIME_LIMIT_SEC`) and `RALPH_MAX_ITERATIONS` are the *real* safety brakes in both modes — they bound the loop even if claude bills nothing per call.

## Common runs

```bash
# Short shakedown (3 iterations, ~15 min cadence, 1 USD budget each)
RALPH_INTERVAL_SEC=900 RALPH_MAX_ITERATIONS=3 RALPH_PER_ITER_BUDGET_USD=1 \
  bash .agents/loops/improve-android-skill/run.sh

# Verify wiring without spending API dollars
RALPH_DRY_RUN=1 RALPH_MAX_ITERATIONS=2 RALPH_INTERVAL_SEC=5 \
  bash .agents/loops/improve-android-skill/run.sh

# Tail the live loop log in another terminal
# (use -F, not -f, so it works even if you start tailing before the runner)
tail -F .agents/loops/improve-android-skill/iterations/loop.log

# Watch the most recent iteration's claude output
tail -F "$(ls -t .agents/loops/improve-android-skill/iterations/iter-*.log | head -1)"
```

## Safety

- Runs `claude -p --dangerously-skip-permissions`. The user opted in.
- Per-iteration budget cap (`--max-budget-usd`) and wall-clock cap (`timeout(1)`).
- Iteration logs land in `iterations/` (gitignored), state files are committed.
- Agent is instructed to commit on a feature branch (`ralph/improve-android-skill`)
  and **never push** — review locally before any `git push`.
- Agent is instructed not to `rm -rf` outside `.metrics/` and `iterations/`.

If anything misbehaves: `Ctrl-C` the runner, then `git status` / `git log
ralph/improve-android-skill` to see exactly what was done. Reset to a clean
state with `git checkout main` and `git branch -D ralph/improve-android-skill`
if you want to start over.

## Tuning the loop

- **Loop is going off-track.** Don't try to fix it with prompt patches mid-loop.
  Stop it. Edit `state/PLAN.md` (and/or `CONTEXT.md`, `LEARNINGS.md`) to
  redirect, then restart. The pattern relies on disposable plans + persistent
  facts.
- **Loop is too cautious / too aggressive.** Edit `PROMPT.md` long-term
  guidance. The runner will pick up the new prompt on the next iteration.
- **Iterations finish in 5 minutes.** Lower `RALPH_INTERVAL_SEC` so you don't
  burn wall-clock waiting between cheap iterations.
- **Iterations consistently hit the 29-min kill.** Either the tasks in
  `PLAN.md` are too big — split them — or raise `RALPH_PER_ITER_TIME_LIMIT_SEC`
  and `RALPH_INTERVAL_SEC` together (keep ~60s buffer between them).

## What this loop will not do

- It will not push to a remote, open PRs, or run CI.
- It will not change unrelated app code (per `AGENTS.md` "Surgical changes").
- It will not iterate on the iOS side (Android-first per the user's guidance).
- It will not declare a perf win without paired A/B benchmarks.
