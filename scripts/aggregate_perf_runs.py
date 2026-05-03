#!/usr/bin/env python3
"""
Aggregate metrics from repeated `collect_android_gfxinfo_compare.sh` runs (OUTPUT_DIR per run).

Expects: base_dir/run_NNN/gfxinfo-B_longlist_after_scroll.txt (+ optional meminfo-B_longlist_after_scroll.txt)
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from pathlib import Path

# Import sibling parser without package
_scripts = Path(__file__).resolve().parent
if str(_scripts) not in sys.path:
    sys.path.insert(0, str(_scripts))

from parse_gfxinfo_metrics import parse_gfxinfo, parse_meminfo_total_pss_kb  # noqa: E402


def ci95_mean(xs: list[float]) -> tuple[float, float, float]:
    """Return (mean, low, high) for 95% CI of the mean (t approx: use z=1.96 for n>=30)."""
    n = len(xs)
    if n < 2:
        m = xs[0] if xs else float("nan")
        return m, m, m
    m = statistics.mean(xs)
    sd = statistics.stdev(xs)
    se = sd / math.sqrt(n)
    t = 2.045 if n < 30 else 1.96  # rough df=29 two-tailed
    return m, m - t * se, m + t * se


def load_run(run_dir: Path) -> dict[str, float | int | None]:
    gfx = run_dir / "gfxinfo-B_longlist_after_scroll.txt"
    mem = run_dir / "meminfo-B_longlist_after_scroll.txt"
    if not gfx.exists():
        raise FileNotFoundError(gfx)
    metrics = parse_gfxinfo(gfx.read_text(encoding="utf-8", errors="replace"))
    if mem.exists():
        metrics["mem_total_pss_kb"] = parse_meminfo_total_pss_kb(mem.read_text(encoding="utf-8", errors="replace"))
    metrics["run_dir"] = str(run_dir)
    return metrics


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("base_dir", type=Path, help="Directory containing run_* subfolders")
    ap.add_argument("--json", action="store_true", help="Emit summary JSON only")
    args = ap.parse_args()

    runs = sorted(args.base_dir.glob("run_*"))
    if not runs:
        print(f"no run_* directories under {args.base_dir}", file=sys.stderr)
        sys.exit(2)

    rows: list[dict[str, float | int | None]] = []
    for rd in runs:
        try:
            rows.append(load_run(rd))
        except FileNotFoundError as e:
            print(f"skip {rd}: {e}", file=sys.stderr)

    if len(rows) < 2:
        print("need at least 2 successful runs for aggregate stats", file=sys.stderr)

    keys = [
        "attached_views",
        "janky_pct",
        "p90_ms",
        "p99_ms",
        "total_frames",
        "render_nodes_kb",
        "mem_total_pss_kb",
    ]

    summary: dict[str, dict[str, float]] = {}
    for key in keys:
        vals: list[float] = []
        for r in rows:
            v = r.get(key)
            if v is None:
                continue
            vals.append(float(v))
        if len(vals) < 2:
            continue
        med = statistics.median(vals)
        m, lo, hi = ci95_mean(vals)
        summary[key] = {
            "n": float(len(vals)),
            "median": float(med),
            "mean": float(m),
            "ci95_low": float(lo),
            "ci95_high": float(hi),
            "stdev": float(statistics.stdev(vals)),
        }

    if args.json:
        print(json.dumps({"runs": len(rows), "metrics": summary}, indent=2))
        return

    print(f"Aggregated {len(rows)} runs under {args.base_dir}\n")
    print(f"{'metric':<22} {'n':>4} {'median':>10} {'mean':>10} {'95%CI_low':>12} {'95%CI_high':>12} {'stdev':>8}")
    for key in keys:
        if key not in summary:
            continue
        s = summary[key]
        print(
            f"{key:<22} {int(s['n']):4d} {s['median']:10.2f} {s['mean']:10.2f} "
            f"{s['ci95_low']:12.2f} {s['ci95_high']:12.2f} {s['stdev']:8.2f}"
        )

    print(
        "\nInterpretation: non-overlapping 95% CIs between two conditions (separate aggregate runs) suggest a",
        "real shift if variance (stdev) is controlled; mobile timings are noisy — prefer n≥15–30.",
        sep="\n",
    )


if __name__ == "__main__":
    main()
