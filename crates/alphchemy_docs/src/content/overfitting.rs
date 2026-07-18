pub const OVERFITTING: &str = r####"# Overfitting

This page describes **overfitting**, which happens when the optimizer finds a strategy that fits training data but does not generalize to unseen data.

## What overfitting means here

Overfitting is when a strategy looks strong on the training window because it captured random quirks of that specific price history. The test window is the main check against that failure mode.

**Example:**

| Window | Excess Sharpe |
| --- | --- |
| Training | +0.65 |
| Validation | +0.12 |
| Test | -0.20 |

The training score is high, validation is weaker, and test is negative.

## Why experiments are unusually prone to it

The optimizer can build many combinations of feature comparisons, gates, branches, references, and thresholds. Long searches with large action sequences can discover patterns that are only useful inside one historical window.

## What protects against it

**Protections:**
- `test_size`:
    - description: keeps a test window out of the search loop
- `val_size`:
    - description: creates a validation window used to pick the winner and stop the search
- `cv_folds`:
    - description: repeats the search across multiple windows
- `val_patience`:
    - description: stops the optimizer when validation score stops improving
- penalties:
    - description: subtract score for complex networks and feature usage
- `excess_sharpe`:
    - description: rewards strategy performance over buy-and-hold performance
- `is_invalid`:
    - description: forces metrics to zero for negative equity or zero exits

## Warning Signals

**Signals:**
- training much greater than validation and test:
    - description: strongest sign that the strategy learned training noise
- validation much greater than test:
    - description: validation winner may have been lucky
- many more `train_improvements` than `val_improvements`:
    - description: optimizer kept improving training after validation stopped
- inconsistent test results across folds:
    - description: strategy does not work across market regimes
- exit reason mix changes across splits:
    - description: behavior may depend on one specific regime

## Controls

**Controls:**
- penalties:
    - description: increase `node`, node-type, `used_feat`, or `unused_feat` penalties to prefer simpler networks
- `seq_len`:
    - description: decrease to limit how much each candidate can build
- `max_iters`:
    - description: decrease to reduce search time
- `val_patience`:
    - description: decrease to stop sooner after validation stops improving
- `cv_folds`:
    - description: increase to require agreement across more windows
- `feats`:
    - description: reduce feature count to shrink the search space
- `base_net`:
    - description: start from fewer nodes

## Further reading

- experiment/experiment: Train, validation, and test fold splits
- optimizer/optimizer: Validation scoring and early stopping
- network/logic_net: Logic penalties
- network/decision_net: Decision penalties
"####;
