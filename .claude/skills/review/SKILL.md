---
name: review
description: In-depth codebase review across the Flutter frontend, Python agents, and Rust experiment runner. Surfaces cross-cutting bugs, schema drift between languages, dead code, and CLAUDE.md guideline violations.
---

# Codebase review

Do an in-depth review across all three runtimes in this repo. Find logic bugs, unfinished features, failure points, and inconsistencies. Do NOT write or edit code — propose fixes in prose.

## Before reviewing

1. Read root `CLAUDE.md` to ground yourself in the user's coding guidelines, the Supabase schema, and project structure.
2. Read `/Users/aryuh/.claude/projects/-Users-aryuh-Documents-alphchemy/memory/MEMORY.md` — the auto-memory index. Apply any rule there as if it's in CLAUDE.md (e.g. "no `?? default` for non-null columns", "bloc state cast with `as`", "no prop drilling", compute-unit rule).
3. Skim the three runtime roots so you know where shared concepts live:
   - `frontend/alphchemy/` — Flutter / Dart. UI, blocs (`lib/blocs/...`), models (`lib/model/...`), widgets (`lib/widgets/...`), pages (`lib/pages/...`).
   - `agents/alphchemy/` — Python. Agent commands (`src/agents/commands.py`), prompts, analysis query / filter logic.
   - `experiments/alphchemy/` — Rust. Experiment runner, data fetch (`src/fetch_data.rs`).

## Severity scale (1 most severe → 6 least)

1. **Cross-runtime schema drift** — Dart `fromJson`/`toJson`, Python pydantic models, and Rust serde structs disagree on shape, field names, types, or enum strings for any shared payload (notebook submission, experiment payload, feature set values, submission discriminator, filter types, agent context messages).
2. **Subtle logic bugs** — off-by-one, wrong comparator, swapped variables, missed state branch, etc.
3. **Crash / hard failure points** — unwrap on possibly-null, cast that can throw, unreachable-by-assumption `switch` arms, unhandled error paths that drop UI into a broken state.
4. **Cross-runtime nullability mismatch** — Supabase column declared `NOT NULL` but read as nullable in code (or vice versa); Dart `final X foo` paired with Python `foo: X | None`.
5. **Dead, redundant, or over-abstracted code** — unused exports, abandoned event handlers, duplicate logic across files that should be a single helper, copy-paste branches, **excessive helper functions** (a function whose body is a single call to another function, a one-liner helper used in only one place, wrapper methods that add no behavior), pass-through layers that exist only to forward args.
6. **Bottlenecks / other** — O(n²) inside a stream listener, repeated parsing/copying in hot paths, anything else worth flagging.

## Cross-cutting checks to always run

Beyond runtime-local bugs, sweep these:

- **Shared payloads parity**: for each shape that crosses runtimes, open the Dart model + Python model + Rust struct side by side. Compare field names, types, defaults, optionality.
- **Supabase column nullability**: cross-reference root `CLAUDE.md` (Supabase Tables section) with how each runtime reads each column. Flag `?? default` on non-null columns. Flag unwraps on nullable columns.
- **Enum string parity**: status enums (`AgentStatus`, `NotebookStatus`, `FeatureSetStatus`, submission `type`, filter `type`) must produce identical strings in JSON across all three runtimes.
- **Bloc state transitions**: error / loaded / working transitions in each Flutter bloc must match the documented flow. Loaded-with-banner should never collapse to a top-level `Error` state when the bloc was loaded.
- **CLAUDE.md guideline violations**: no trailing commas, compute-unit rule, DRY, KISS, no prop drilling of bloc state, no `?? default` on non-null sources, required-not-default params, etc.
- **Abstraction smell**: any helper that exists only to call another helper, single-use one-line functions, wrapper widgets/classes that only pass props through, redirector methods (`a()` → `b()`). Inline them. KISS rule in `CLAUDE.md` plus `feedback_inline_over_helpers` memory.
- **Unnecessary prop drilling**: bloc state (or any slice of it) threaded through constructor params of child widgets when the child could read it directly via `context.read<TheBloc>()`. Flag every `final SomeState state;` / `final SomeModel model;` field on a widget whose ancestor already provides the bloc. 

## Output format

Table with at most 10 rows, sorted by severity ascending (severity 1 first). Stop at 10 — do not pad.

```
| # | Sev | Location | Problem | Proposed fix |
|---|-----|----------|---------|--------------|
| 1 | 2   | frontend/.../notebook_bloc.dart:256 | <terse description> | <terse fix> |
```

Use `path:line` (no full absolute paths needed; from repo root). Reference CLAUDE.md or memory rule by short name when the finding violates one (e.g. "violates `feedback_no_default_fallback_for_non_null_columns`").

After the table, add two short lines:

- **What looked good**: one sentence on a strong pattern observed (e.g. consistent use of typed state classes, clean schema-to-model mapping).
- **Scope of this review**: one sentence on what was and wasn't read (e.g. "Skimmed frontend + agents; did not exhaustively walk `experiments/alphchemy/src/`").

## What to SKIP

Do not flag any of these (signal-to-noise):

- Style / formatting nits already permitted by `CLAUDE.md` (double-quotes vs single, no trailing commas, brace placement, etc.). Assume the file follows them.
- Missing tests / test coverage gaps — only mention if a bug is *only* catchable via tests.
- Comment quality, unless a comment actively misleads the reader.
- Naming preferences beyond the explicit short-but-descriptive rule in CLAUDE.md.
- TODO / FIXME markers that the user clearly left intentionally.
- Lint warnings already silenced via `// ignore:` comments — assume intentional.

## Hard rules

- **Never write or edit code.** Use Read / Grep / Glob only. Propose fixes in the table.
- **Never run linters, formatters, tests, or any non-readonly tool.**
- **Cap at 10 findings.** If you have more, drop the lowest-severity ones.
- **Stay terse.** Each `Problem` and `Proposed fix` is one sentence.
