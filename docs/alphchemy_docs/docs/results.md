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
| Best Train Network | The network produced by applying the best training sequence to the base network. |
| Best Validation Sequence | The sequence of build operations that produced the highest validation score. This is the strategy that gets re-scored on training, validation, and test below. |
| Best Validation Network | The network produced by applying the best validation sequence to the base network. |
| Train Improvements | A line on the optimizer chart — each point is an iteration where the training score reached a new best. |
| Validation Improvements | Same, for validation. |

A healthy search produces many validation improvements throughout, not just at the start. If training keeps improving but validation does not, the search is overfitting to the training window — see [experiment/overfitting.md](experiment/overfitting.md).

## Metric blocks

Each block reports how the winning strategy would have performed in that window. Only the metrics requested in the schema's `metrics` field appear. Possible metrics:

| Metric | Meaning |
|---|---|
| Is Invalid | True if the strategy went broke (equity ever negative) or never closed a position. Both cases force every metric to zero. Treat invalid blocks as "no signal". (Reported separately, not a selectable metric.) |
| Sharpe | The strategy equity's Sharpe ratio over the window. |
| Excess Sharpe | The strategy's Sharpe minus buy-and-hold's Sharpe over the same window. Positive = beat holding Bitcoin. Often the metric the search maximizes. |
| Max Drawdown | Largest peak-to-trough decline of the equity curve, as a fraction (0.2 = 20%). |
| Mean Hold Time | Average bars (hours) a position was held. |
| Std Hold Time | Standard deviation of hold times. |
| Total Entries | Number of positions opened. |
| Total Exits | Number of positions closed. (Total Entries − Total Exits) is the count still open at the end. |
| Signal Exits | Closed because the strategy's exit signal fired. |
| Stop Loss Exits | Closed by the stop-loss cap. |
| Take Profit Exits | Closed by the take-profit cap. |
| Max Hold Exits | Closed because the max-hold-time limit was reached. |

Full definitions: [experiment/backtest.md](experiment/backtest.md).

## What the dashboard charts show

The results dashboard shows:

1. **Metric charts** — one bar chart per requested metric (training / validation / test bars per fold). These are grouped under a single collapsible "Metric Charts" toggle, collapsed by default. The drop from training → validation → test is your overfitting indicator.
2. **Equity Curve chart** — a line chart of the equity over time for the selected fold, with one line each for training, validation, and test.
3. **Metrics table** — every requested metric, in three columns (training / validation / test).
4. **Optimizer chart** — training and validation improvement lines over iterations. Lines diverging means the search started memorizing training noise.

Read [experiment/overfitting.md](experiment/overfitting.md) for how to interpret these together.

## Error case

If the experiment failed (bad configuration, no data for the time range, etc.) the results page will show a single error message instead of the per-fold panels.
