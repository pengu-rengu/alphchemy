pub const EXPERIMENT: &str = r####"# Experiment

This page describes **experiments**, which configure the historical data range, fold splits, backtest settings, and strategy.

## Fields

**Fields:**
- `val_size`:
    - description: fraction of each fold used for validation
    - constraints: must be > 0.0
- `test_size`:
    - description: fraction of each fold used for testing
    - constraints: must be > 0.0, and `val_size + test_size` must be < 1.0
- `cv_folds`:
    - description: number of folds to run
    - constraints: must be integer > 0
- `fold_size`:
    - description: fraction of the full data range used by each fold
    - constraints: must be > 0.0 and <= 1.0
- `symbol`:
    - description: market symbol to backtest
    - constraints: must be a supported symbol
- `time_interval`:
    - description: duration of each market data bar
    - constraints: must be `1h`
    - default: `1h`
    - aliases: `interval`
- `start_timestamp`:
    - description: inclusive start of the historical data range
    - constraints: must be before `end_timestamp`
- `end_timestamp`:
    - description: inclusive end of the historical data range
    - constraints: must be after `start_timestamp`
- `backtest_schema`:
    - description: trading simulation settings
    - constraints: must be a valid backtest schema
- `strategy`:
    - description: strategy to optimize and evaluate
    - constraints: must be a valid strategy

**Format:**
```
val_size: ...
test_size: ...
cv_folds: ...
fold_size: ...
symbol: ...
time_interval: ...
start_timestamp: ...
end_timestamp: ...
backtest_schema:
  ...
strategy:
  ...
```

**Example:**
```
val_size: 0.2
test_size: 0.2
cv_folds: 4
fold_size: 0.7
symbol: BTC_USDT
time_interval: 1h
start_timestamp: 2024-05-01T00:00:00Z
end_timestamp: 2024-11-01T00:00:00Z
backtest_schema:
  ...
strategy:
  ...
```

## Folds

A **fold** is one slice of the timeline split into training, validation, and test windows.

The training fraction is whatever remains after validation and test:

```
train_size = 1.0 - val_size - test_size
```

Every fold is split in chronological order:
- training first
- validation second
- test last

The optimizer runs once per fold. It searches on the training window, tracks validation score during the search, picks the best validation candidate, then re-simulates that candidate on all three windows.

## Further reading

- experiment/backtest: Trading simulation settings and metrics
- experiment/strategy: Features, network, optimizer, and entry/exit rules
- experiment/overfitting: How fold settings affect overfitting
"####;
