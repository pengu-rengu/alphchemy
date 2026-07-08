# Results

This page describes **results**, which report fold windows, optimizer output, and backtest metrics for completed experiments.

Results are an array of fold result objects.

## Fold Result

**Fields:**
- `train_start_timestamp`:
    - description: inclusive start timestamp of the training window
- `train_end_timestamp`:
    - description: inclusive end timestamp of the training window
- `val_start_timestamp`:
    - description: inclusive start timestamp of the validation window
- `val_end_timestamp`:
    - description: inclusive end timestamp of the validation window
- `test_start_timestamp`:
    - description: inclusive start timestamp of the test window
- `test_end_timestamp`:
    - description: inclusive end timestamp of the test window
- `opt_results`:
    - description: optimizer output for the fold
- `train_results`:
    - description: backtest result for the selected validation winner on the training window
- `val_results`:
    - description: backtest result for the selected validation winner on the validation window
- `test_results`:
    - description: backtest result for the selected validation winner on the test window

**Format:**
```
{
    "train_start_timestamp": "...",
    "train_end_timestamp": "...",
    "val_start_timestamp": "...",
    "val_end_timestamp": "...",
    "test_start_timestamp": "...",
    "test_end_timestamp": "...",
    "opt_results": {},
    "train_results": {},
    "val_results": {},
    "test_results": {}
}
```

## Optimizer Results

**Fields:**
- `iters`:
    - description: number of optimizer iterations completed
- `best_train_seq`:
    - description: action sequence with the best training score
- `best_train_net`:
    - description: network produced by `best_train_seq`
- `best_val_seq`:
    - description: action sequence with the best validation score
- `best_val_net`:
    - description: network produced by `best_val_seq`
- `train_improvements`:
    - description: iterations where training score reached a new best
- `val_improvements`:
    - description: iterations where validation score reached a new best

The strategy reported in `train_results`, `val_results`, and `test_results` is `best_val_net`, not `best_train_net`.

## Backtest Result

**Fields:**
- `is_invalid`:
    - description: whether equity went negative or zero positions closed
- `metrics`:
    - description: map of requested metric names to values
- `equity_curve`:
    - description: downsampled equity series with at most 100 points

**Format:**
```
{
    "is_invalid": false,
    "metrics": {
        "excess_sharpe": 0.1
    },
    "equity_curve": [10000.0, 10020.0]
}
```

## Interpretation

Training, validation, and test metrics should be read together. Large training results with weak validation or test results are a sign of overfitting.

`test_results` are the out-of-sample results. They are the main measure of whether the selected strategy generalized beyond the search windows.

## Error Case

If an experiment fails, results may contain an error object instead of fold results.

**Format:**
```
{
    "error": "...",
    "is_internal": false
}
```

## Further reading

- experiment/backtest: Metric and invalid-result definitions
- optimizer/optimizer: Training and validation improvement behavior
- experiment/overfitting: How to interpret train, validation, and test gaps
