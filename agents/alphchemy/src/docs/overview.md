# Overview

This page describes **Alphchemy**, which runs experiments that search for profitable trading strategies.

An experiment defines a time range, features, a network, actions, penalties, an optimizer, and trading rules. Alphchemy evaluates candidate strategies with cross-validated backtests and reports fold-level training, validation, and test results.

## Experiment Flow

1. Pull OHLC data for `symbol` between `start_timestamp` and `end_timestamp`.
2. Compute features from `strategy.feats`.
3. Split the data into folds using `cv_folds`, `fold_size`, `val_size`, and `test_size`.
4. Optimize candidate networks on each training window.
5. Pick the candidate with the best validation score.
6. Re-score that candidate on the training, validation, and test windows.

## Strategy Types

- `logic`: feature comparisons and boolean gate nodes
- `decision`: branch and reference nodes walked as a decision trail

Logic and decision strategies share the same experiment, feature, backtest, optimizer, and results structure.

## Further reading

- experiment/experiment: Top-level experiment fields and fold behavior
- source/source_format: Complete source syntax
- features/features: Feature IDs and indicators
- network/network: Network and node pointer behavior
- actions/actions: Actions the optimizer can apply
- optimizer/optimizer: Search and stop behavior
- results: Result fields and interpretation
- notebooks: Notebook objects and query tiles
- query: Query objects, results, and syntax
