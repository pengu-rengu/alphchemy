# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
cargo build          # Build the project
cargo run            # Run the binary
cargo test           # Run all tests
cargo test <name>    # Run a single test by name
```

## Rust Specifications

- No trailing commas
- Edition 2024

## Architecture

Alphchemy is a genetic algorithm framework for optimizing network-based strategies (e.g. logic circuits, decision trees) applied to financial feature data.

### Core Abstractions

The system is built on three generic traits that are composed into a `Strategy<T: Network, P: Penalties<T>, A: Actions<T>>`:

- **`Network`** — evaluates input features and exposes node values. Implementations: `LogicNet` (logic gates), `DecisionNet` (decision trees)
- **`Penalties<N: Network>`** — scores network complexity (node count, recurrence, feature usage). Each network type has its own penalties struct
- **`Actions<N: Network>`** — defines mutations that can be applied to a network (adding nodes, setting parameters, navigating). Networks are constructed by replaying action sequences on a base network via `construct_net()`

### Module Layout

- **`features/`** — `Feature` trait and implementations (`Constant`, `RawReturns`) for computing feature matrices from OHLC data via `feat_matrix()`
- **`network/`** — `Network` trait, `NodePtr`/`Anchor` types, and two implementations: `LogicNet` (gate-based) and `DecisionNet` (tree-based)
- **`actions/`** — `Actions` trait, `ActionsState` for tracking mutation context, `Action` enum (17 variants), and per-network implementations
- **`optimizer/`** — `GeneticOpt` runs the GA loop (tournament selection, single-point crossover, mutation) with `POState` tracking population fitness and `StopConds` for patience-based early stopping

### Key Design Patterns

- Networks are represented as action sequences (genomes) that are replayed to construct the network, enabling genetic operators to work on flat vectors
- `LogicActions` supports meta-actions (sequences of actions mapped to a single action) and configurable allowed gate types
