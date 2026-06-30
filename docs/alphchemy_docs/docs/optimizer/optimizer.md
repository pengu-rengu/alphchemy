# Optimizer

The **Optimizer** node and the **Stop Conditions** node together control the search. In every fold, the optimizer tries many candidate strategies on the training window, scoring each one, and uses the scores to steer toward better candidates. Eventually it stops (per Stop Conditions) and reports the best candidate it found.

Add one **Optimizer** child and one **Stop Conditions** child under your Strategy.

## How scoring works

Each candidate is built, simulated on the training window, and scored as:

```
score = weighted sum of objective metrics on the training window − complexity penalty
```

- The objective metrics and their weights come from the `objectives` map on the Optimizer node; each metric must be one of the backtest `metrics`. The score is `Σ weight × metric` — see [experiment/backtest.md](../experiment/backtest.md).
- The complexity penalty comes from the Penalties node on your Strategy — see [network/logic_net.md](../network/logic_net.md) or [network/decision_net.md](../network/decision_net.md).

The same candidate is also scored on the **validation** window. The validation score is used for two things:

1. **Picking the winner**. At the end, the best-on-validation candidate (not the best-on-training) is reported and re-scored on training, validation, and test.
2. **Early stopping**. If validation stops improving for Validation Patience iterations, the search ends.

Both the training and validation best are tracked throughout the search. Both are shown on the results page as the *Training Improvements* and *Validation Improvements* lines.

## Stop Conditions fields

The search stops as soon as **any** of following is true:

| Field | Stops the search when… |
|---|---|
| Max Iterations | Total iterations reach this value. Must be > 0. |
| Train Patience | The training score hasn't improved for this many iterations. |
| Validation Patience | The validation score hasn't improved for this many iterations. |

### How to set them

| Field | Suggestion |
|---|---|
| Max Iterations | 500–2000. A hard ceiling so a runaway search can't burn forever. |
| Train Patience | Set generously, e.g. 200. Rarely the active stop in practice. |
| Validation Patience | Around 100 to start. **Your main brake against overfitting.** Tighter = stops sooner. |

If the search stops by Validation Patience, you'll see Training Improvements continue past the iteration of the last Validation Improvement — that's a normal sign that early stopping fired correctly.

## What "good search behavior" looks like

A healthy search log:

- Training Improvements and Validation Improvements both grow steadily through the early iterations.
- They flatten around the same time.
- Total iterations stop well below Max Iterations — early stopping fired naturally.

A pathological search log:

- Training Improvements keep adding entries late into the search.
- Validation Improvements has very few entries, mostly early.
- The reported test score is far worse than the validation score.

The latter is overfitting — see [experiment/overfitting.md](../experiment/overfitting.md).

## Optimizer settings

See [optimizer/genetic.md](genetic.md).
