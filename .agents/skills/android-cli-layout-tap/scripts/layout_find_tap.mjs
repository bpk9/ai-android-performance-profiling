#!/usr/bin/env node
/**
 * Extract tap coordinates from Android CLI `android layout -p` JSON (stdin or -f).
 * JSON parse + fuzzy match + center extraction in one process.
 */
import { readFileSync } from "node:fs";
import { stdout, stderr } from "node:process";

/** POSIX awk SUBSEP for SequenceMatcher-style matching blocks. */
const SUBSEP = "\x1c";

const RE_NON_LABEL = /[^a-z0-9_\s,|]/gi;
const RE_WS = /\s+/g;
const RE_TRIM = /^ +| +$/g;
const RE_CENTER_STR = /^\s*\[(-?[0-9]+)\s*,\s*(-?[0-9]+)\]\s*$/;

function usage(stream = stdout) {
  stream.write(`Usage: layout_find_tap.mjs [-f FILE] [--find LABEL] [--min-score S]
  [--desc-contains S] [--not-desc-contains S] [--text-contains S] [--state-contains S]
  [--nth N] [--list] [--compact] [--max-list N] [--list-all-labels]
  [--json] [--explain] [--suggest N] [--label-width W] [--adb [SERIAL]]
  [--batch-json FILE]

Batch: -f LAYOUT.json --batch-json STEPS.json (FILE may be - for stdin; layout must use -f).
  STEPS is a JSON array of objects with optional keys: find, minScore, desc, ndesc, text, state, nth, explain.
  Stdout: one "x y" line per step, or one JSON array with --json.

Pipe: android layout --device=SERIAL -p | layout_find_tap.mjs [--find ...]
`);
}

function die(msg, code = 2) {
  stderr.write(`${msg}\n`);
  process.exit(code);
}

function parseArgs(argv) {
  const o = {
    file: "",
    find: "",
    minScore: 0.42,
    desc: "",
    ndesc: "",
    text: "",
    state: "",
    nth: 0,
    list: false,
    compact: false,
    maxList: 80,
    listAll: false,
    json: false,
    explain: false,
    suggest: 12,
    labw: 72,
    adbMode: false,
    adbSerial: "",
    batchJson: "",
  };
  const skipEnv = (process.env.LAYOUT_FIND_TAP_SKIP_SUGGEST || "").toLowerCase();
  o.skip = /^(1|true|yes)$/.test(skipEnv) ? 1 : 0;

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const need = () => {
      const v = argv[++i];
      if (v == null) die(`layout_find_tap: missing value for ${a}`);
      return v;
    };
    switch (a) {
      case "-h":
      case "--help":
        usage();
        process.exit(0);
      case "-f":
      case "--file":
        o.file = need();
        break;
      case "--find":
        o.find = need();
        break;
      case "--min-score":
        o.minScore = Number(need());
        break;
      case "--desc-contains":
        o.desc = need();
        break;
      case "--not-desc-contains":
        o.ndesc = need();
        break;
      case "--text-contains":
        o.text = need();
        break;
      case "--state-contains":
        o.state = need();
        break;
      case "--nth":
        o.nth = Number(need());
        break;
      case "--list":
        o.list = true;
        break;
      case "--compact":
        o.compact = true;
        break;
      case "--max-list":
        o.maxList = Number(need());
        break;
      case "--list-all-labels":
        o.listAll = true;
        break;
      case "--json":
        o.json = true;
        break;
      case "--explain":
        o.explain = true;
        break;
      case "--suggest":
        o.suggest = Number(need());
        break;
      case "--label-width":
        o.labw = Number(need());
        break;
      case "--adb": {
        const next = argv[i + 1];
        if (next != null && !next.startsWith("-")) {
          o.adbSerial = next;
          o.adbMode = true;
          i++;
        } else {
          o.adbMode = true;
          o.adbSerial = process.env.ANDROID_SERIAL || "";
        }
        break;
      }
      case "--batch-json":
        o.batchJson = need();
        break;
      default:
        stderr.write(`layout_find_tap: unknown option: ${a}\n`);
        usage(stderr);
        process.exit(2);
    }
  }
  return o;
}

function sanitizeField(s) {
  return String(s ?? "")
    .replace(/\t/g, " ")
    .replace(/\n/g, " ")
    .replace(/\r/g, " ");
}

function parseCenter(node) {
  const c = node.center;
  if (c == null) return null;
  if (Array.isArray(c) && c.length === 2) {
    const x = Number(c[0]);
    const y = Number(c[1]);
    if (Number.isFinite(x) && Number.isFinite(y)) return [x, y];
    return null;
  }
  if (typeof c === "string") {
    const m = c.match(RE_CENTER_STR);
    if (m) return [Number(m[1]), Number(m[2])];
  }
  return null;
}

function combinedLabel(node) {
  const parts = [
    node["content-desc"] ?? null,
    node.text ?? null,
    node["resource-id"] ?? null,
    node.class ?? null,
  ]
    .filter((x) => x != null)
    .map((x) => String(x));
  return parts.join(" | ");
}

function stateJoined(node) {
  const s = node.state;
  if (s == null) return "";
  if (Array.isArray(s)) return s.map(String).join(" ");
  return String(s);
}

function nodesArr(root) {
  if (Array.isArray(root)) return root;
  if (root != null && typeof root === "object") {
    if (Array.isArray(root.nodes)) return root.nodes;
    if (Array.isArray(root.elements)) return root.elements;
    if (Array.isArray(root.layout)) return root.layout;
    throw new Error("Expected JSON array or object with nodes/elements/layout array");
  }
  throw new Error("Expected JSON array or object");
}

function extractRows(parsed) {
  const arr = nodesArr(parsed);
  const rows = [];
  for (let ik = 0; ik < arr.length; ik++) {
    const node = arr[ik];
    const xy = parseCenter(node);
    if (!xy) continue;
    rows.push({
      idx: ik,
      x: xy[0],
      y: xy[1],
      desc: sanitizeField(node["content-desc"]),
      text: sanitizeField(node.text),
      state: sanitizeField(stateJoined(node)),
      label: sanitizeField(combinedLabel(node)),
      stateObj: node.state,
    });
  }
  return rows;
}

// --- SequenceMatcher-style ratio (difflib-compatible) ---

function smBuildB2j(b) {
  const counts = Object.create(null);
  const b2j = Object.create(null);
  const lb = b.length;
  const n = lb;
  for (let j = 0; j < lb; j++) {
    const ch = b.charAt(j);
    const k = (counts[ch] = (counts[ch] || 0) + 1);
    b2j[ch + SUBSEP + k] = j;
  }
  if (n >= 200) {
    const ntest = Math.floor(n / 100) + 1;
    for (const ch2 of Object.keys(counts)) {
      if (counts[ch2] > ntest) {
        const lim = counts[ch2];
        for (let kk = 1; kk <= lim; kk++) delete b2j[ch2 + SUBSEP + kk];
        delete counts[ch2];
      }
    }
  }
  return { counts, b2j };
}

function smFindLongestMatch(a, alo, ahi, b, blo, bhi, counts, b2j) {
  let besti = alo;
  let bestj = blo;
  let bestsize = 0;
  const j2len = Object.create(null);
  for (let i = alo; i < ahi; i++) {
    const newj2len = Object.create(null);
    const chA = a.charAt(i);
    const nch = counts[chA] || 0;
    for (let idx = 1; idx <= nch; idx++) {
      const j = b2j[chA + SUBSEP + idx];
      if (j < blo) continue;
      if (j >= bhi) break;
      const jp = String(j - 1);
      const k = (jp in j2len ? j2len[jp] : 0) + 1;
      newj2len[String(j)] = k;
      if (k > bestsize) {
        besti = i - k + 1;
        bestj = j - k + 1;
        bestsize = k;
      }
    }
    for (const jj of Object.keys(j2len)) delete j2len[jj];
    for (const jj of Object.keys(newj2len)) j2len[jj] = newj2len[jj];
  }
  while (besti > alo && bestj > blo && a.charAt(besti - 1) === b.charAt(bestj - 1)) {
    besti--;
    bestj--;
    bestsize++;
  }
  while (
    besti + bestsize < ahi &&
    bestj + bestsize < bhi &&
    a.charAt(besti + bestsize) === b.charAt(bestj + bestsize)
  ) {
    bestsize++;
  }
  return { besti, bestj, bestsize };
}

function sortBlocksAsc(blocks) {
  blocks.sort((A, B) => (A.bi !== B.bi ? A.bi - B.bi : A.bj - B.bj));
}

function smMatchingTotal(a, b, la, lb) {
  const { counts, b2j } = smBuildB2j(b);
  const stack = [{ alo: 0, ahi: la, blo: 0, bhi: lb }];
  const blocks = [];
  while (stack.length) {
    const { alo, ahi, blo, bhi } = stack.pop();
    const { besti: ti, bestj: tj, bestsize: tk } = smFindLongestMatch(
      a,
      alo,
      ahi,
      b,
      blo,
      bhi,
      counts,
      b2j,
    );
    if (tk > 0) {
      blocks.push({ bi: ti, bj: tj, bk: tk });
      if (alo < ti && blo < tj) stack.push({ alo, ahi: ti, blo, bhi: tj });
      if (ti + tk < ahi && tj + tk < bhi) stack.push({ alo: ti + tk, ahi, blo: tj + tk, bhi });
    }
  }
  if (blocks.length === 0) return 0;
  sortBlocksAsc(blocks);
  let i1 = 0;
  let j1 = 0;
  let k1 = 0;
  let tot = 0;
  for (const z of blocks) {
    const i2 = z.bi;
    const j2 = z.bj;
    const k2 = z.bk;
    if (i1 + k1 === i2 && j1 + k1 === j2) k1 += k2;
    else {
      if (k1 > 0) tot += k1;
      i1 = i2;
      j1 = j2;
      k1 = k2;
    }
  }
  if (k1 > 0) tot += k1;
  return tot;
}

function smRatio(a, b) {
  const la = a.length;
  const lb = b.length;
  const denom = la + lb;
  if (denom === 0) return 1.0;
  return (2.0 * smMatchingTotal(a, b, la, lb)) / denom;
}

function normalizeLabel(s) {
  let t = s.toLowerCase();
  t = t.replace(RE_NON_LABEL, " ");
  t = t.replace(RE_WS, " ");
  return t.replace(RE_TRIM, "");
}

function tokenOverlapRatio(qn, ln) {
  const qseen = Object.create(null);
  for (const w of qn.split(/\s+/)) {
    if (w && w.length >= 2) qseen[w] = 1;
  }
  const lseen = Object.create(null);
  for (const w of ln.split(/\s+/)) {
    if (w && w.length >= 2) lseen[w] = 1;
  }
  const sq = Object.keys(qseen).length;
  if (sq === 0) return 0.0;
  let inter = 0;
  for (const k of Object.keys(qseen)) {
    if (k in lseen) inter++;
  }
  return inter / sq;
}

/** `qNorm` = normalizeLabel(query); `lab` = row.label. */
function fuzzyScoreNormalized(qNorm, lab) {
  const ln = normalizeLabel(lab);
  if (qNorm === "" || ln === "") return 0.0;
  if (ln.includes(qNorm)) {
    const denom = ln.length < 1 ? 1 : ln.length;
    const subsc = 0.88 + 0.12 * (qNorm.length / denom);
    return subsc < 1.0 ? subsc : 1.0;
  }
  const tok = tokenOverlapRatio(qNorm, ln);
  const ratio = smRatio(qNorm, ln);
  let bestw = 0.0;
  for (const w of ln.split(/\s+/)) {
    if (w.length < 2) continue;
    const r = smRatio(qNorm, w);
    if (r > bestw) bestw = r;
  }
  const blended = 0.28 * tok + 0.32 * ratio + 0.4 * bestw + (tok > 0 ? 0.08 : 0.0);
  return blended > 1.0 ? 1.0 : blended;
}

function fuzzyScore(query, lab) {
  return fuzzyScoreNormalized(normalizeLabel(query), lab);
}

function nodeMatches(row, opts) {
  if (opts.desc !== "" && !row.desc.includes(opts.desc)) return false;
  if (opts.ndesc !== "" && row.desc.includes(opts.ndesc)) return false;
  if (opts.text !== "" && !row.text.includes(opts.text)) return false;
  if (opts.state !== "" && !row.state.includes(opts.state)) return false;
  return true;
}

function round4(x) {
  return Math.round(x * 10000) / 10000;
}

function statePyRepr(jsonStr) {
  return jsonStr.replace(/"/g, "'");
}

function stateJsonLine(stateObj) {
  return statePyRepr(JSON.stringify(stateObj !== undefined ? stateObj : null));
}

const byScoreThenIdx = (A, B) => (B.sc !== A.sc ? B.sc - A.sc : A.idx - B.idx);

function truncateLabel(lab, maxLen) {
  if (lab.length <= maxLen) return lab;
  return lab.slice(0, maxLen - 1) + "…";
}

function writeSampleRows(rows, lim, stream, maxLab = 100) {
  const n = Math.min(lim, rows.length);
  for (let i = 0; i < n; i++) {
    const row = rows[i];
    let lab = row.label.replace(/\n/g, " ");
    lab = truncateLabel(lab, maxLab);
    stream.write(`  idx=${row.idx}  center=${row.x},${row.y}  label='${lab}'\n`);
  }
}

function printFallbackSample(rows, lim) {
  stderr.write(
    "layout_find_tap: no match. Sample nodes with center (use --list-all-labels for the full list):\n",
  );
  writeSampleRows(rows, lim, stderr);
}

function printSuggestions(rows, query, lim) {
  const hint = query.trim();
  if (hint === "") {
    printFallbackSample(rows, lim);
    return;
  }
  const hintNorm = normalizeLabel(hint);
  const scored = rows.map((row) => ({
    sc: fuzzyScoreNormalized(hintNorm, row.label),
    row,
  }));
  scored.sort(byScoreThenIdx);
  const top = scored.length ? scored[0].sc : -1;
  if (top < 0 || top < 0.06) {
    stderr.write(
      `layout_find_tap: hint '${hint}' does not resemble any label; sample nodes with center:\n`,
    );
    writeSampleRows(rows, lim, stderr);
    return;
  }
  stderr.write("layout_find_tap: no match for filters/find. Did you mean one of these?\n");
  const headn = Math.min(lim, scored.length);
  for (let i = 0; i < headn; i++) {
    const { sc, row } = scored[i];
    stderr.write(
      `  score=${sc.toFixed(2)}  idx=${row.idx}  center=${row.x},${row.y}  desc=${row.desc}  text=${row.text}\n`,
    );
  }
}

function buildMatches(rows, opts) {
  const out = [];
  if (opts.find !== "") {
    const qNorm = normalizeLabel(opts.find);
    for (const row of rows) {
      if (!nodeMatches(row, opts)) continue;
      const sc = fuzzyScoreNormalized(qNorm, row.label);
      if (sc >= opts.minScore) {
        out.push({
          idx: row.idx,
          x: row.x,
          y: row.y,
          sc,
          desc: row.desc,
          text: row.text,
          lb: row.label,
          raw: row,
        });
      }
    }
    out.sort(byScoreThenIdx);
  } else {
    for (const row of rows) {
      if (!nodeMatches(row, opts)) continue;
      out.push({
        idx: row.idx,
        x: row.x,
        y: row.y,
        sc: 1.0,
        desc: row.desc,
        text: row.text,
        lb: row.label,
        raw: row,
      });
    }
  }
  return out;
}

function emitNoMatch(rows, hint, opts) {
  if (!opts.skip) {
    if (hint !== "") printSuggestions(rows, hint, opts.suggest);
    else printFallbackSample(rows, opts.suggest);
  }
  stderr.write("layout_find_tap: no matching nodes with a valid center\n");
  process.exit(1);
}

function readInput(opts) {
  return opts.file ? readFileSync(opts.file, "utf8") : readFileSync(0, "utf8");
}

function readBatchSpec(path) {
  const text = path === "-" ? readFileSync(0, "utf8") : readFileSync(path, "utf8");
  let j;
  try {
    j = JSON.parse(text);
  } catch (e) {
    die(`layout_find_tap: invalid batch JSON: ${e.message}`, 2);
  }
  if (!Array.isArray(j)) die("layout_find_tap: --batch-json must be a JSON array", 2);
  return j;
}

/** Per-step options for --batch-json (single layout parse, many matches). */
function optsForBatchStep(globalOpts, item, i) {
  if (item == null || typeof item !== "object") {
    die(`layout_find_tap: batch step ${i} must be an object`, 2);
  }
  const g = globalOpts;
  return {
    file: g.file,
    find: String(item.find ?? ""),
    minScore: Number(item.minScore ?? g.minScore),
    desc: String(item.desc ?? ""),
    ndesc: String(item.ndesc ?? ""),
    text: String(item.text ?? ""),
    state: String(item.state ?? ""),
    nth: Number(item.nth ?? 0),
    list: false,
    compact: g.compact,
    maxList: g.maxList,
    listAll: false,
    json: false,
    explain: Boolean(item.explain) || g.explain,
    suggest: g.suggest,
    labw: g.labw,
    adbMode: false,
    adbSerial: "",
    skip: g.skip,
  };
}

function validateBatchWithSingleMode(opts) {
  if (opts.find !== "")
    die("layout_find_tap: do not combine --find with --batch-json; use batch JSON objects", 2);
  if (opts.desc !== "" || opts.ndesc !== "" || opts.text !== "" || opts.state !== "")
    die(
      "layout_find_tap: do not combine filter flags with --batch-json; use batch JSON objects",
      2,
    );
  if (opts.list || opts.listAll || opts.adbMode)
    die("layout_find_tap: --list / --list-all-labels / --adb are incompatible with --batch-json", 2);
}

function mainBatch(rows, globalOpts, batchQueries) {
  if (batchQueries.length === 0) die("layout_find_tap: empty --batch-json array", 2);

  const out = [];
  for (let i = 0; i < batchQueries.length; i++) {
    const optsStep = optsForBatchStep(globalOpts, batchQueries[i], i);
    const matches = buildMatches(rows, optsStep);
    const hint = `${optsStep.find} ${optsStep.desc} ${optsStep.text}`.trim();
    if (matches.length === 0) {
      stderr.write(`layout_find_tap: batch step ${i} (of ${batchQueries.length}) — no match\n`);
      emitNoMatch(rows, hint, optsStep);
    }
    const nm = matches.length;
    if (optsStep.nth < 0 || optsStep.nth >= nm) {
      stderr.write(
        `layout_find_tap: batch step ${i}: nth ${optsStep.nth} out of range (${nm} matches)\n`,
      );
      process.exit(1);
    }
    const pick = matches[optsStep.nth];
    if (optsStep.explain) {
      stderr.write(
        `layout_find_tap: batch step ${i} idx=${pick.idx} score=${pick.sc.toFixed(2)} label='${pick.lb}'\n`,
      );
    }
    out.push({
      x: pick.x,
      y: pick.y,
      idx: pick.idx,
      score: round4(pick.sc),
      label: pick.lb,
      "content-desc": pick.desc,
      text: pick.text,
    });
  }
  if (globalOpts.json) {
    stdout.write(JSON.stringify(out) + "\n");
  } else {
    for (const p of out) {
      stdout.write(`${p.x} ${p.y}\n`);
    }
  }
}

function mainSync(rows, opts) {
  if (rows.length === 0) {
    stderr.write("layout_find_tap: invalid JSON or empty nodes\n");
    process.exit(2);
  }

  if (opts.listAll) {
    for (const row of rows) {
      let lab = row.label.replace(/\n/g, " ");
      lab = truncateLabel(lab, opts.labw);
      stdout.write(`${row.idx}\t${row.x}\t${row.y}\t${lab}\n`);
    }
    process.exit(0);
  }

  const matches = buildMatches(rows, opts);
  let hint = opts.find;
  if (hint === "") hint = `${opts.desc} ${opts.text}`;
  hint = hint.trim();

  const nm = matches.length;

  if (opts.list) {
    if (nm === 0) emitNoMatch(rows, hint, opts);
    const stop = Math.min(nm, opts.maxList);
    for (let j = 0; j < stop; j++) {
      const m = matches[j];
      const st = stateJsonLine(m.raw.stateObj);
      if (opts.compact) {
        let lab = m.lb;
        if (lab.length > opts.labw) lab = truncateLabel(lab, opts.labw);
        stdout.write(`${m.idx}\t${m.x}\t${m.y}\t${lab}\t${st}\n`);
      } else {
        const cd = m.desc.replace(/\n/g, " ");
        const tx = m.text.replace(/\n/g, " ");
        stdout.write(`${m.idx}\t${m.x}\t${m.y}\t'${cd}'\t'${tx}'\t${st}\n`);
      }
    }
    if (nm > opts.maxList) {
      stderr.write(
        `layout_find_tap: truncated to ${opts.maxList} rows (${nm} matches); increase --max-list\n`,
      );
    }
    process.exit(0);
  }

  if (nm === 0) emitNoMatch(rows, hint, opts);

  if (opts.nth < 0 || opts.nth >= nm) {
    stderr.write(`layout_find_tap: --nth ${opts.nth} out of range (${nm} matches)\n`);
    process.exit(1);
  }

  const pick = matches[opts.nth];
  if (opts.explain) {
    stderr.write(
      `layout_find_tap: match idx=${pick.idx} score=${pick.sc.toFixed(2)} label='${pick.lb}'\n`,
    );
  }

  if (opts.json) {
    stdout.write(
      JSON.stringify({
        x: pick.x,
        y: pick.y,
        idx: pick.idx,
        score: round4(pick.sc),
        label: pick.lb,
        "content-desc": pick.desc,
        text: pick.text,
      }) + "\n",
    );
  } else if (opts.adbMode) {
    if (opts.adbSerial !== "")
      stdout.write(`adb -s ${opts.adbSerial} shell input tap ${pick.x} ${pick.y}\n`);
    else stdout.write(`adb shell input tap ${pick.x} ${pick.y}\n`);
  } else {
    stdout.write(`${pick.x} ${pick.y}\n`);
  }
}

function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (opts.batchJson) {
    validateBatchWithSingleMode(opts);
    if (!opts.file) die("layout_find_tap: --batch-json requires -f LAYOUT.json (layout stdin is ambiguous)", 2);
    if (opts.batchJson === "-" && opts.file === "-") {
      die("layout_find_tap: use -f FILE for layout when --batch-json reads stdin", 2);
    }
    let text;
    try {
      text = readFileSync(opts.file, "utf8");
    } catch (e) {
      die(`layout_find_tap: cannot read layout file: ${e.message}`, 2);
    }
    const batchQueries = readBatchSpec(opts.batchJson);
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch (e) {
      die(`layout_find_tap: invalid layout JSON: ${e.message}`, 2);
    }
    let rows;
    try {
      rows = extractRows(parsed);
    } catch (e) {
      die(`layout_find_tap: invalid layout: ${e.message}`, 2);
    }
    mainBatch(rows, opts, batchQueries);
    return;
  }

  let text;
  try {
    text = readInput(opts);
  } catch (e) {
    die(`layout_find_tap: cannot read input: ${e.message}`, 2);
  }
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (e) {
    die(`layout_find_tap: invalid JSON: ${e.message}`, 2);
  }
  let rows;
  try {
    rows = extractRows(parsed);
  } catch (e) {
    die(`layout_find_tap: invalid JSON: ${e.message}`, 2);
  }
  mainSync(rows, opts);
}

try {
  main();
} catch (e) {
  die(`layout_find_tap: ${e.message}`, 2);
}
