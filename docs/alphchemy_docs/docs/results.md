# Results

When an experiment finishes, the results page shows one panel per **fold**. Each panel has time boundaries for that fold's three windows, a summary of how the search went, and three columns of trading metrics — training, validation, test — for the winning strategy.

## Per-fold contents

Each fold panel reports:

- **Time boundaries** — the start/end of the fold overall, and the start/end of its three windows (training, validation, test).
- **Search summary** — see *Search summary* below.
- **Three metric blocks** — one each for the training, validation, and test window. See *Metric blocks* below.

## Search summary

This section tells you what the search engine did inside this fold:

| Item | Meaning |
|---|---|
| Iterations | How many generations the search ran before stopping. Usually less than the configured maximum because it ran out of improvements. |
| Best Train Sequence | The sequence of build operations that produced the highest training score. Shown for inspection. |
| Best Validation Sequence | The sequence of build operations that produced the highest validation score. This is the strategy that gets re-scored on training, validation, and test below. |
| Train Improvements | A line on the optimizer chart — each point is an iteration where the training score reached a new best. |
| Validation Improvements | Same, for validation. |

A healthy search produces many validation improvements throughout, not just at the start. If training keeps improving but validation does not, the search is overfitting to the training window — see [experiment/overfitting.md](experiment/overfitting.md).

## Metric blocks

Each block reports how the winning strategy would have performed in that window:

| Metric | Meaning |
|---|---|
| Is Invalid | True if the strategy went broke (equity ever negative) or never closed a position. Both cases force the score to zero. A block with entries and zero total exits is invalid. Treat invalid blocks as "no signal". |
| Excess Sharpe | The strategy's Sharpe ratio minus buy-and-hold's Sharpe ratio over the same window. Positive = beat holding Bitcoin. This is the metric the search is maximizing. |
| Mean Hold Time | Average bars (hours) a position was held. |
| Std Hold Time | Standard deviation of hold times. |
| Entries | Number of positions opened. |
| Total Exits | Number of positions closed. (Entries − Total Exits) is the count still open at the end. |
| Signal Exits | Closed because the strategy's exit rule fired. |
| Stop Loss Exits | Closed by the stop-loss cap. |
| Take Profit Exits | Closed by the take-profit cap. |
| Max Hold Exits | Closed because the max-hold-time limit was reached. |

Full definitions: [experiment/backtest.md](experiment/backtest.md).

## What the dashboard charts show

Four charts summarize the results across folds:

1. **Excess Sharpe chart** — training / validation / test bars per fold. The drop from training → validation → test is your overfitting indicator.
2. **Metrics table** — every metric above, in three columns (training / validation / test).
3. **Optimizer chart** — training and validation improvement lines over iterations. Lines diverging means the search started memorizing training noise.
4. **Exit reasons chart** — the four exit counts as stacked bars across training / validation / test. Shifts across windows tell you whether the strategy is behaving consistently.

Read [experiment/overfitting.md](experiment/overfitting.md) for how to interpret these together.

## Error case

If the experiment failed (bad configuration, no data for the time range, etc.) the results page will show a single error message instead of the per-fold panels.
