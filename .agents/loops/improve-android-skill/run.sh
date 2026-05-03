#!/usr/bin/env bash
# Ralph loop for improving the android-cli-layout-tap skill (and the related
# Android performance / benchmark / analysis skills it composes with).
#
# Pattern: Geoffrey Huntley's "Ralph" loop — a `while` loop that runs
# `claude -p` against a fresh context each iteration. Persistent state lives
# on disk under ./state/ (PLAN.md, CONTEXT.md, CHANGELOG.md, LEARNINGS.md),
# so each iteration reads where the last one left off.
#
# Each iteration is wall-clock-capped (default ~29 min). Iterations are spaced
# to start every $RALPH_INTERVAL_SEC seconds (default 30 min): if an iteration
# finishes early we sleep, if it runs over we just start the next one
# immediately and log the overrun.
#
# Subscription vs API key:
#   - On Claude Max, the runner does NOT pass --max-budget-usd (that flag only
#     meters pay-as-you-go API spend; on Max it's a no-op). Spend is governed
#     by your subscription quota: 5-hour rolling windows + weekly caps that
#     reset Fridays 17:00 UTC. All models share that pool; Sonnet stretches
#     it further than Opus.
#   - Set RALPH_PER_ITER_BUDGET_USD=N to opt in to the API-key cap (only
#     useful when ANTHROPIC_API_KEY is set or you've otherwise switched off
#     the subscription).
#   - If an iteration dies fast (<60s exit) AND its log looks like a 429 /
#     "rate limit" / "quota" message, we back off for RATE_LIMIT_BACKOFF_SEC
#     (default 1 hour) before the next attempt — cheap retries against a
#     hard 429 just burn the rest of your weekly cap.
#
# Stop conditions (any one of):
#   1. Reached $RALPH_MAX_ITERATIONS iterations.
#   2. The agent emitted "$RALPH_COMPLETION_SIGNAL" in $RALPH_COMPLETION_THRESHOLD
#      consecutive iterations (default 3).
#   3. The user kills the loop (SIGINT/SIGTERM — handled cleanly).
#
# Usage:
#   bash .agents/loops/improve-android-skill/run.sh
#
# Common overrides:
#   RALPH_INTERVAL_SEC=900 \
#   RALPH_MAX_ITERATIONS=5 \
#   RALPH_PER_ITER_BUDGET_USD=2 \
#   bash .agents/loops/improve-android-skill/run.sh
#
# Dry run (skip the actual claude call):
#   RALPH_DRY_RUN=1 bash .agents/loops/improve-android-skill/run.sh

set -uo pipefail
# Note: deliberately NOT using `set -e` — a single iteration failure must
# not kill the loop. We capture exit codes per-iteration into the log.

# ---------- config (env-overridable) ----------
INTERVAL_SEC="${RALPH_INTERVAL_SEC:-1800}"          # 30 min between iteration starts
MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-100}"
PER_ITER_TIME_LIMIT_SEC="${RALPH_PER_ITER_TIME_LIMIT_SEC:-1740}"  # 29 min hard kill (leaves 60s buffer before next start)
COMPLETION_SIGNAL="${RALPH_COMPLETION_SIGNAL:-RALPH_LOOP_DONE_FOR_NOW}"
COMPLETION_THRESHOLD="${RALPH_COMPLETION_THRESHOLD:-3}"
MODEL="${RALPH_MODEL:-}"                            # optional, e.g. claude-4.5-sonnet
DRY_RUN="${RALPH_DRY_RUN:-0}"

# Optional API-key spend cap. Empty by default — `--max-budget-usd` only meters
# pay-as-you-go API spend; on a Claude Max subscription it's a no-op. Set this
# to a number (e.g. RALPH_PER_ITER_BUDGET_USD=3) when running against an API key.
PER_ITER_BUDGET_USD="${RALPH_PER_ITER_BUDGET_USD:-}"

# Rate-limit handling. If an iteration exits in less than RATE_LIMIT_FAST_FAIL_SEC
# AND its log matches RATE_LIMIT_PATTERN, we assume a 5-hour-window or weekly
# cap was hit and back off for RATE_LIMIT_BACKOFF_SEC before the next iteration.
# Cheap retries against a hard 429 just burn quota faster.
RATE_LIMIT_BACKOFF_SEC="${RALPH_RATE_LIMIT_BACKOFF_SEC:-3600}"      # 1 hour
RATE_LIMIT_FAST_FAIL_SEC="${RALPH_RATE_LIMIT_FAST_FAIL_SEC:-60}"    # any iter <60s exit is suspicious
RATE_LIMIT_PATTERN="${RALPH_RATE_LIMIT_PATTERN:-rate.?limit|usage limit|429|quota|too many requests|reset.*in}"

# ---------- paths ----------
LOOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LOOP_DIR/../../.." && pwd)"
STATE_DIR="$LOOP_DIR/state"
ITER_DIR="$LOOP_DIR/iterations"
PROMPT_FILE="$LOOP_DIR/PROMPT.md"
LOOP_LOG="$ITER_DIR/loop.log"

mkdir -p "$STATE_DIR" "$ITER_DIR"

log() { printf '[ralph %s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOOP_LOG"; }

# ---------- preflight ----------
if [ "$DRY_RUN" = "0" ]; then
  command -v claude >/dev/null || { log "FATAL: claude CLI not on PATH"; exit 1; }
fi
[ -f "$PROMPT_FILE" ] || { log "FATAL: missing $PROMPT_FILE"; exit 1; }

# Resolve a wall-clock guard binary. Prefer GNU timeout / gtimeout (kills the
# whole process group). Fall back to a bash background-kill if neither exists.
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="$(command -v timeout)"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="$(command -v gtimeout)"
fi

# Resume iteration numbering from existing logs, so a restart doesn't clobber.
LAST_N="$(ls "$ITER_DIR"/iter-*.log 2>/dev/null \
  | sed -E 's|.*/iter-([0-9]+).*|\1|' \
  | sort -n | tail -1)"
START_N="$(( ${LAST_N:-0} + 1 ))"
END_N="$(( START_N + MAX_ITERATIONS - 1 ))"

# Trap to ensure we report on Ctrl-C or kill.
trap 'log "received signal — exiting after current iteration"; STOP_REQUESTED=1' INT TERM
STOP_REQUESTED=0

log "starting Ralph loop"
log "  loop dir          : $LOOP_DIR"
log "  repo root         : $REPO_ROOT"
log "  iteration range   : $START_N..$END_N"
log "  interval          : ${INTERVAL_SEC}s ($((INTERVAL_SEC/60)) min)"
log "  per-iter time cap : ${PER_ITER_TIME_LIMIT_SEC}s"
log "  per-iter budget   : ${PER_ITER_BUDGET_USD:+\$}${PER_ITER_BUDGET_USD:-(none — Max subscription assumed)}"
log "  rate-limit backoff: ${RATE_LIMIT_BACKOFF_SEC}s after fast-fail (<${RATE_LIMIT_FAST_FAIL_SEC}s) matching /$RATE_LIMIT_PATTERN/i"
log "  completion signal : $COMPLETION_SIGNAL × $COMPLETION_THRESHOLD"
log "  model             : ${MODEL:-default}"
log "  dry run           : $DRY_RUN"
log "  timeout binary    : ${TIMEOUT_BIN:-bash-fallback}"

consecutive_done=0

for n in $(seq "$START_N" "$END_N"); do
  [ "$STOP_REQUESTED" = "1" ] && { log "stop requested — breaking"; break; }

  ts="$(date +%Y%m%d-%H%M%S)"
  iter_id="$(printf 'iter-%04d-%s' "$n" "$ts")"
  iter_log="$ITER_DIR/$iter_id.log"

  log "iteration $n start (log: $(basename "$iter_log"))"
  iter_start=$SECONDS

  # Build the iteration prompt. Keep it short — the heavy guidance is in
  # PROMPT.md, which the agent reads itself. We just inject context that
  # changes per iteration (number, date, paths).
  prompt_text=$(cat <<EOF
You are iteration $n of the Ralph loop at $LOOP_DIR.
Today's date is $(date +%Y-%m-%d).
Iteration log file (your stdout/stderr is captured here): $iter_log

Read $PROMPT_FILE in full, then follow the iteration playbook there.
EOF
)

  cli_args=(
    -p
    --dangerously-skip-permissions
  )
  [ -n "$PER_ITER_BUDGET_USD" ] && cli_args+=(--max-budget-usd "$PER_ITER_BUDGET_USD")
  [ -n "$MODEL" ] && cli_args+=(--model "$MODEL")

  if [ "$DRY_RUN" = "1" ]; then
    {
      echo "[dry-run] would invoke: claude ${cli_args[*]} <prompt-elided>"
      echo "[dry-run] prompt was:"
      echo "$prompt_text"
      # Optional: simulate a rate-limit hit (for testing the backoff branch).
      # Set RALPH_DRY_RUN_FAIL=1 to make every dry-run iteration emit a 429.
      [ "${RALPH_DRY_RUN_FAIL:-0}" = "1" ] && echo "Error: 429 rate_limit_exceeded — usage limit reached, reset in 47 min"
    } >"$iter_log" 2>&1
    iter_exit="${RALPH_DRY_RUN_FAIL:-0}"
    [ "$iter_exit" = "1" ] && iter_exit=2  # any non-zero — pretend claude failed
  else
    # Wall-clock guard. timeout(1) sends SIGTERM, then SIGKILL after --kill-after.
    if [ -n "$TIMEOUT_BIN" ]; then
      ( cd "$REPO_ROOT" && \
        "$TIMEOUT_BIN" --kill-after=30 "${PER_ITER_TIME_LIMIT_SEC}s" \
          claude "${cli_args[@]}" "$prompt_text" \
      ) >"$iter_log" 2>&1
      iter_exit=$?
    else
      # Portable fallback: run claude in background, kill after the time cap.
      ( cd "$REPO_ROOT" && claude "${cli_args[@]}" "$prompt_text" ) \
        >"$iter_log" 2>&1 &
      cpid=$!
      ( sleep "$PER_ITER_TIME_LIMIT_SEC"; kill -TERM "$cpid" 2>/dev/null; \
        sleep 30; kill -KILL "$cpid" 2>/dev/null ) &
      gpid=$!
      wait "$cpid" 2>/dev/null
      iter_exit=$?
      kill "$gpid" 2>/dev/null; wait "$gpid" 2>/dev/null
    fi
  fi

  iter_dur=$((SECONDS - iter_start))
  log "iteration $n end   exit=$iter_exit duration=${iter_dur}s"

  # Completion-signal counting (consecutive iterations that emit the signal).
  if grep -qF "$COMPLETION_SIGNAL" "$iter_log" 2>/dev/null; then
    consecutive_done=$((consecutive_done + 1))
    log "  completion signal observed (${consecutive_done}/${COMPLETION_THRESHOLD})"
  else
    consecutive_done=0
  fi

  if [ "$consecutive_done" -ge "$COMPLETION_THRESHOLD" ]; then
    log "$COMPLETION_THRESHOLD consecutive completion signals — stopping"
    break
  fi

  # Decide how long to sleep before the next iteration.
  #
  # Default: keep the configured cadence (start every INTERVAL_SEC).
  # Special case: if the iteration died fast AND its log smells like a
  # subscription rate-limit (5h-window or weekly cap), back off for
  # RATE_LIMIT_BACKOFF_SEC instead — retrying against a hard 429 just
  # burns the rest of your weekly quota.
  sleep_for="$(( INTERVAL_SEC > iter_dur ? INTERVAL_SEC - iter_dur : 0 ))"
  sleep_reason="cadence"

  if [ "$iter_dur" -lt "$RATE_LIMIT_FAST_FAIL_SEC" ] \
     && [ "$iter_exit" -ne 0 ] \
     && grep -qiE "$RATE_LIMIT_PATTERN" "$iter_log" 2>/dev/null; then
    sleep_for="$RATE_LIMIT_BACKOFF_SEC"
    sleep_reason="rate-limit backoff (fast-fail + log matched /$RATE_LIMIT_PATTERN/i)"
  fi

  if [ "$sleep_for" -gt 0 ]; then
    log "  sleeping ${sleep_for}s — $sleep_reason"
    # Sleep in 5s chunks so SIGINT is responsive.
    remaining="$sleep_for"
    while [ "$remaining" -gt 0 ] && [ "$STOP_REQUESTED" = "0" ]; do
      chunk=$(( remaining > 5 ? 5 : remaining ))
      sleep "$chunk"
      remaining=$((remaining - chunk))
    done
  else
    log "  iteration overran cadence by $((iter_dur - INTERVAL_SEC))s — starting next immediately"
  fi
done

log "loop exited"
