#!/usr/bin/env python3
"""Extract numeric metrics from `adb shell dumpsys gfxinfo <pkg>` text (and optional meminfo dump)."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def _float_pct(s: str) -> float | None:
    m = re.search(r"\(([0-9.]+)%\)", s)
    return float(m.group(1)) if m else None


def _int_after_colon(line: str) -> int | None:
    m = re.search(r":\s*(\d+)", line)
    return int(m.group(1)) if m else None


def _ms(line: str) -> float | None:
    m = re.search(r":\s*(\d+)ms", line)
    return float(m.group(1)) if m else None


def parse_gfxinfo(text: str) -> dict[str, float | int | None]:
    out: dict[str, float | int | None] = {}
    for line in text.splitlines():
        if line.startswith("Total frames rendered:"):
            out["total_frames"] = _int_after_colon(line)
        elif line.startswith("Janky frames:") and "legacy" not in line.lower():
            out["janky_pct"] = _float_pct(line)
            j = re.search(r":\s*(\d+)\s", line)
            out["janky_frames"] = int(j.group(1)) if j else None
        elif line.startswith("50th percentile:"):
            out["p50_ms"] = _ms(line)
        elif line.startswith("90th percentile:"):
            out["p90_ms"] = _ms(line)
        elif line.startswith("95th percentile:"):
            out["p95_ms"] = _ms(line)
        elif line.startswith("99th percentile:"):
            out["p99_ms"] = _ms(line)
        elif line.startswith("Total attached Views"):
            out["attached_views"] = _int_after_colon(line)
        elif re.match(r"^\s+\d+\s+views,", line):
            vm = re.search(r"^\s+(\d+)\s+views,\s+([0-9.]+)\s+kB", line)
            if vm:
                out["hierarchy_views"] = int(vm.group(1))
                out["render_nodes_kb"] = float(vm.group(2))
    return out


def parse_meminfo_total_pss_kb(text: str) -> int | None:
    """First TOTAL line: Pss Total is typically the first numeric column after TOTAL."""
    for line in text.splitlines():
        if not line.strip().startswith("TOTAL"):
            continue
        parts = line.split()
        # TOTAL PssTotal PrivateDirty ... — column positions vary; take second token if numeric
        for tok in parts[1:]:
            if tok.isdigit():
                return int(tok)
    return None


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("gfxinfo_file", type=Path, help="Path to gfxinfo dump text")
    ap.add_argument("--meminfo", type=Path, help="Optional meminfo dump for PSS total")
    ap.add_argument("--json", action="store_true", help="Print JSON to stdout")
    args = ap.parse_args()

    raw = args.gfxinfo_file.read_text(encoding="utf-8", errors="replace")
    metrics = parse_gfxinfo(raw)
    if args.meminfo and args.meminfo.exists():
        mem = parse_meminfo_total_pss_kb(args.meminfo.read_text(encoding="utf-8", errors="replace"))
        metrics["mem_total_pss_kb"] = mem

    if args.json:
        print(json.dumps(metrics, indent=2))
    else:
        for k in sorted(metrics.keys()):
            print(f"{k}={metrics[k]}")
    sys.exit(0)


if __name__ == "__main__":
    main()
