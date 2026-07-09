# Optimizer

This page describes **optimizer behavior**, including scoring, validation selection, and stop conditions.

Every fold runs an optimizer against the training window. The same candidate is also scored against the validation window so the final winner can be selected by validation score.

## How scoring works

Each candidate is built, simulated on the training window, and scored as:

```
score = weighted sum of objective metrics - complexity penalty
```

Objective metrics and weights come from `opt.objectives`. Each objective metric must also be listed in `backtest_schema.metrics`.

Complexity penalty comes from `strategy.penalties`.

## Validation

Validation is used for two things:

1. Pick the winner at the end of optimization.
2. Stop the search when validation score stops improving.

The best training sequence and best validation sequence are both tracked in results.

## Stop Conditions

The search stops as soon as **any** of following is true:

**Fields:**
- `max_iters`:
    - description: maximum optimizer iterations
    - constraints: must be integer > 0
- `train_patience`:
    - description: maximum iterations without training score improvement
    - constraints: must be integer >= 0
- `val_patience`:
    - description: maximum iterations without validation score improvement
    - constraints: must be integer >= 0

**Format:**
```
stop_conds:
  max_iters: ...
  train_patience: ...
  val_patience: ...
```

**Example:**
```
stop_conds:
  max_iters: 500
  train_patience: 200
  val_patience: 100
```

## Search Behavior

Healthy search usually has `train_improvements` and `val_improvements` improving early and flattening around the same time.

When `train_improvements` keeps growing but `val_improvements` stops early, the optimizer is likely overfitting to the training window.

## Further reading

- optimizer/genetic: Genetic optimizer fields
- experiment/backtest: Metric definitions
- experiment/overfitting: Interpreting training, validation, and test gaps
