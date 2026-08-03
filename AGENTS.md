# AGENTS.md

This file provides guidance to OpenAI Codex when working with code in this codebase.

## What is this?

At a high level, this is a system where AI agents run experiments and analyze data to optimize trading strategies.

## Plan Mode Guideline

When in plan mode, always put code snippets in your plan

## General Guidelines
- No trailing commas
- DRY: Refactor out any redundant code
- YAGNI: No unnecessary guard clauses. A lot can be done with simple try/catch. Sometimes try/catch isn't event needed.
- KISS: Always default to most simple, minimal implementation. Make assumptions as necessary, but be sure to mention them. Absolutely no spaghetti code.
- Short but descriptive variable/parameter/function names; absolutely no one letter names allowed, except for i as an index in for loops.
- Prefer double quotes; only use single quotes for nested strings
- In general, functions or classes/structs that depend on others should be placed lower in the file, than those do not.
- Instead of silent failures by ignoring or default values, prefer explicit errors. For example, throw an error on default of switch statement instead using default value. Or throw an error if key doesn't exist when parsing json instead of using default value. Don't throw errors for everything though. For example accessing a non-existent json key already throws an error by itself.
- No excessive newline formatting. I have line wrap enabled, so long statements shouldn't be a problem.

## Python Guidelines
- Everything except for variables should have type annotations
- Use `uv`. Don't use `pip` or `python`.
- Unless stated otherwise, only write tests in /tests/agent_tests folder.

## Flutter/Dart Guidelines
- Only use blocs, no cubits
- Prefer widgets over helper methods
- Prefer to have functions inside classes instead of outside of them
- Prefer Material 3 widgets instead of older widgets (e.g. DropdownMenu instead of DropdownButton)
- Do not use const modifiers on widgets that need to be rebuilt. Do not delete "// ignore: prefer_const_***" comments
- Avoid unnecesary prop drilling. Use context.read instead
- Don't use `dart format`

## Rust Guidelines
- If necessary, prefer using generics over explicitly declaring a variables type
- Unless stated otherwise, only write tests in /tests folder; do not write tests in codebase files.

## Hegel Test Guidelines
- One test or submodule of tests per function
- If one behavioral branch, a  standalone `#[hegel::test]`
- Two or more branches: a `mod <fn>_tests` submodule holding one `#[derive(Debug)] struct TestContext`, one `#[hegel::composite] fn gen_context` that does arrange plus act, and one independent `#[hegel::test]` per branch that only asserts.
- Parameters in gen_context determine branch
- Each branch test has its own expected value from the TestContext fields. Never repeat one shared `assert_eq!(ctx.result, Ok(ctx.expected))` line across branches.
- At most one invalid test per function, no matter how many error paths exist. gen_context picks which error path to hit: boolean flags for two invalid cases (`let first = draw_invalid && tc.draw(booleans()); let second = draw_invalid && !first;`), an `InvalidCase` enum drawn with `sampled_from` for three or more.
- Generators shared by more than one submodule (`gen_filter`, `gen_path_segment`) go at `mod tests` level, above the submodules.
- Mock all seams with `.times(...)`, `.with(...)`/`.withf(...)`, `.return_const(...)`.

## "Compute Unit" Guideline
This is a strict guideline meant to make the codebase cleaner and easier to read

__RULE__: Each statement must have at most one compute unit of each type

Types of compute units:
- Math operations: +, -, *, /, %
- Comparison operators: >, <, >=, <=
- Boolean operations: and, or
- Variable/property assignment operations: x = y
- Function/constructors calls: f(x) or Struct { } in rust.
- Closures: (x) => y
- Type conversions: x as y

Not a compute unit:
- Square bracket indexing
- Dot notation

What is a statement:
- A return expression, match arm, or anything that ends with a semicolon

Counting Exceptions:
- Any math operation adding or subtracting 1 or 1.0 doesn't count
- Same consecutive math operations (two +s or two -s) count as one
- Equals (==) and not equals (!=) don't count
- The not boolean operator doesn't count
- A function call with no arguments doesn't count
- Macros/decorators and type declarations/annotations don't count
- tc.draw in hegel tests don't count
- Mockall methods and predicates like .with, .withf, .in_sequence, .times, .returning_st, .return_const, eq, in_iter don't count
- Rust Some(), Ok(), and Err() don't count
- Rust pointers Box, Rc, Cell, and RefCell don't count

Note 1: compute unit rules do not apply to pinescript codegen
Note 2: splitting up statements too much also is also compute unit violation
Note 3: Rust macros like format!() and println!() do count. vec! doesn't count.

# Supabase Tables

Table: `experiments`
`id`: int8, primary key
`last_updated`: timestamptz, default = now()
`title`: text
`experiment`: jsonb, can be null
`results`: jsonb, can be null
`status`: enum "queued", "running", "errored", or "completed"
`source`: text
`user_id`: uuid, foreign key to auth.users.id, can be null
`is_public`: bool, default = false
`benchmark_data`: jsonb, can be null

Table: `notebooks`
`id`: int8, primary key
`last_updated`: timestamptz, default = now()
`title`: text
`queries`: jsonb
`notes`: jsonb
`status`: enum "idle", "working", or "errored"
`error_message`: text, can be null

Table: `convert_jobs`
`id`: int8, primary key
`last_updated`: timestamptz, default = now()
`experiment_id`: int8, foreign key to table `experiments` column `id`
`fold_idx`: int4
`status`: enum "working", "completed", or "errored"
`pinescript`: text, can be null
`error_message`: text, can be null

Table: `validation_jobs`
`id`: int8, primary key
`last_updated`: timestamptz, default = now()
`source`: text
`status`: enum "working", "completed_valid", "completed_invalid", or "errored"
`result_message`: text, can be null

Table: `benchmarks`
`id`: int8, primary key
`last_updated`: timestamptz, default = now()
`title`: text
`user_id`: uuid, foreign key to auth.users.id
`score_path`: text
`active_model`: text, can be null
`cutoff`: timestamptz
