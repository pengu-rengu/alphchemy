# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this?

At a high level, this is a system where AI agents run experiments and analyze data to optimize trading strategies.

## Build Commands

```bash
cargo build          # Build the project
cargo run            # Run the binary
cargo test           # Run all tests
cargo test <name>    # Run a single test by name
```

## Guidelines
- No trailing commas
- DRY: Refactor out any redundant code, even if its only one or two lines
- No fancy one-liners