# AGENTS.md

This file provides guidance to OpenAI Codex when working with code in this codebase.

## What is this?

At a high level, this is a system where AI agents run experiments and analyze data to optimize trading strategies.

## General Guidelines
- No trailing commas
- DRY: Refactor out any redundant code
- YAGNI: No unnecessary guard clauses. A lot can be done with simple try/catch. Sometimes try/catch isn't event needed.
- KISS: Always default to most simple, minimal implementation. Make assumptions as necessary, but be sure to mention them. Absolutely no spaghetti code.
- No fancy one-liners
- Short but descriptive variable/parameter/function names; absolutely no one letter names allowed, except for i as an index
- Prefer double quotes; only use single quotes for nested strings
- In general, functions or classes/structs that depend on others should be placed lower in the file, than those do not. The exception is for circular dependencies

## Python Guidelines
- Everything except for variables should have type annotations
- Use `uv`. Don't use `pip3` or `python3`.

## Flutter/Dart Guidelines
- Only use blocs, no cubits
- Prefer widgets over helper methods
- Prefer to have functions inside classes instead of outside of them
- Prefer Material 3 widgets instead of older widgets (e.g. DropdownMenu instead of DropdownButton)
- Do not delete // ignore: prefer_const_constructors
- Don't use `dart format`

## Rust Guidelines
- If necessary, prefer using generics over explicitly declaring a variables type

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

# Supabase Tables

Table: `experiments`
`id`: int8, primary key
`created_at`: timestamptz, default = now()
`title`: text
`experiment`: jsonb
`results`: jsonb, can be null
`status`: enum "queued", "running", "errored", or "completed"

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
`layout`: jsonb
`notes`: jsonb
`status`: enum "idle", "working", or "errored"
`error_message`: text, can be null