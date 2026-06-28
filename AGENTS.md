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

## Python Guidelines
- Everything except for variables should have type annotations
- Use `uv`. Don't use `pip3` or `python3`.

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
- Do not write tests in codebase files, only in /tests folder

## "Compute Unit" Guideline
This is a strict guideline meant to make the codebase cleaner and easier to read

__RULE__: Each statement must have at most one compute unit of each type

Types of compute units:
- Math operations: +, -, *, /, %
- Comparison operators: >, <, >=, <=
- Boolean operations: and, or
- Variable/property assignment operations: x = y
- Function/constructors calls: f(x)
- Closures: (x) => y
- Type conversions: x as y

Not a compute unit:
- Square bracket indexing
- Dot notation

What is a statement:
- In Rust and Dart, a return expression or anything that ends with a semicolon
- In Python, anything that ends with a new line, excluding multiline strings and line breaks

Counting Exceptions:
- Any math operation adding or subtracting 1 or 1.0 doesn't count
- Same consecutive math operations (two +s or two -s) count as one
- Equals (==) and not equals (!=) don't count
- The not boolean operator doesn't count
- A function call with no arguments doesn't count
- Macros/decorators and type declarations/annotations don't count
- tc.draw in hegel tests

Note: compute unit rules do not apply to pinescript codegen

# Supabase Tables

Table: `experiments`
`id`: int8, primary key
`last_edited`: timestamptz, default = now()
`title`: text
`experiment`: jsonb, can be null
`results`: jsonb, can be null
`status`: enum "queued", "running", "errored", or "completed"
`source`: text

Table: `agent_systems`
`id`: int8, primary key
`last_edited`: timestamptz, default = now()
`title`: text
`schema`: jsonb
`state`: jsonb, can be null
`status`: enum "created", "idle", "working", or "errored"
`user_prompt`: text, can be null
`submissions`: jsonb, default = [].

Table: `feature_sets`
`id`: int8, primary key
`last_edited`: timestamptz, default = now()
`title`: text
`features`: jsonb
`values`: jsonb, can be null
`status`: enum "idle", "working", or "errored"
`start_timestamp`: int8
`end_timestamp`: int8

Table: `notebooks`
`id`: int8, primary key
`last_edited`: timestamptz, default = now()
`title`: text
`queries`: jsonb
`notes`: jsonb
`status`: enum "idle", "working", or "errored"
`error_message`: text, can be null

Table: `pinescript_jobs`
`id`: int8, primary key
`last_edited`: timestamptz, default = now()
`experiment_id`: int8, foreign key to table `experiments` column `id`
`fold_idx`: int4
`status`: enum "working", "completed", or "errored"
`pinescript`: text, can be null
`error_message`: text, can be null