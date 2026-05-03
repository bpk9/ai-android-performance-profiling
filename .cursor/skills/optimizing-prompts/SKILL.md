---
name: optimizing-prompts
description: >-
  Rewrites user and system prompts for clarity, structure, and reliable model
  behavior. Covers role/objective ordering, success criteria, constraints,
  output shape, and stop rules. Use when the user asks to improve, tighten,
  or optimize a prompt; when editing PROMPT.md or agent instructions; or when
  prompts produce vague, inconsistent, or overly long model outputs.
disable-model-invocation: true
---

# Optimizing prompts

## When this applies

Use this skill before or while editing any **instruction block** the model reads: `PROMPT.md`, `AGENTS.md`, Cursor rules, system prompts, or one-off task prompts.

## Principles (short)

1. **Lead with role and outcome** — Who the model is and what “done” looks like, in one or two sentences each.
2. **Prefer outcome over micromanaged steps** — For capable models, define goals, success criteria, constraints, and allowed evidence; avoid long mandatory step lists unless the task is brittle.
3. **Structure beats prose walls** — Use `##` sections and horizontal rules (`---`) so the model can scan. Put **reference material** (metrics lists, APIs) in clearly labeled blocks separate from **instructions**.
4. **End with output and boundaries** — Explicit **output format** (sections, tables, length). **Stop rules**: what not to optimize, when to state assumptions, when to abstain.
5. **Be specific** — Length, audience, stack (e.g. Expo, Android, Datadog RUM), and acronyms **expanded once** in a table or line.
6. **Avoid fluff** — Cut vague adjectives; replace “handle well” with measurable or observable criteria.
7. **Few-shot only when the shape is new** — If the desired answer format is unusual, add 1 short example; otherwise prefer a template over examples.

## Workflow

1. Read the full prompt as-is. Note the **single primary task** (one sentence).
2. List **gaps**: missing success criteria, unclear metrics or tools, no output shape, no stop conditions, ambiguous scope.
3. Rebuild using the **skeleton** below. Merge existing content; do not drop user-specified constraints or verbatim requirements.
4. **Diff mentally**: shorter labels, less duplication, same obligations.
5. If the prompt is for **reasoning-oriented models**, do not add “think step by step” style instructions unless the user asked; rely on clear criteria instead.

## Skeleton (copy and adapt)

```markdown
## Role
[1–2 sentences: persona + domain.]

## Context (optional)
[Facts the model must not assume wrong: stack, environment, data sources.]

## Goal
[User-visible outcome in plain language.]

## Success criteria
[Bullet checklist of what a good answer must contain.]

## Constraints
[Scope, tools, policies, what is out of scope.]

## Reference
[Metrics, APIs, links — tables welcome.]

## Output format
[Numbered sections or a template the answer must follow.]

## Stop rules
[Boundaries, assumptions, abstain conditions.]
```

Not every prompt needs every section. **Omit** sections that add no behavior change; **keep** Goal, Success criteria, and Output format for agent-style tasks.

## Anti-patterns

- One paragraph that mixes role, task, data, and format with no headings.
- Metrics named only as abbreviations with no glossary.
- “Use best practices” without a concrete success checklist.
- Duplicating the same instruction in three places.
- Process-heavy prompts for tasks where only the deliverable and constraints matter.

## Repo touchpoints

- Project task prompts for this workspace often live in `PROMPT.md`; repository-wide agent hints in `AGENTS.md`. Align terminology (metrics names, stack) across both when editing either file.
