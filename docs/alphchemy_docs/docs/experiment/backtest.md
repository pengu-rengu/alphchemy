# Backtest

A backtest replays one strategy against one window of price data and reports how it would have performed. Every fold's results contain three backtests: one against the training window, one against validation, one against test. The trading simulation settings come from the **Backtest Schema** node directly under your Experiment.

## Backtest Schema fields

| Field | Meaning |
|---|---|
| Start Offset | How many bars at the start of each window are skipped before trading is allowed. This gives the indicators time to "warm up" — most rolling indicators are meaningless until they have enough history. Set this to at least the longest indicator window you use. |
| Start Balance | Starting cash, in quote currency (USDT). Must be > 0. |
| Delay | How many bars to wait between a signal and the trade. With Delay = 1, a signal at bar N triggers a trade at bar N+1's close. This models the realistic case where you cannot trade on the same bar you observe the signal. |

## How trades are simulated

At most one position is open at any time. Every bar (after Start Offset), the simulator does three things in order:

1. **Check exits first.** If a position is open, close it if it hit the stop-loss, take-profit, or max-hold-time limit, or if its exit signal fired.
2. **Check entries.** If no position is open and the entry signal fires, open a position of `Qty` units at the current close price — provided there is enough cash.
3. **Mark to market.** Update equity = cash balance + (current close × open position size).

A position is opened at the current bar's close price. It is closed at the current bar's close price on whichever bar the exit fires. There are no fees, slippage, or partial fills in the simulation — be aware your live results will be worse than the backtest.

## Exit reasons

The open position can be closed for four reasons:

| Reason | Triggered when |
|---|---|
| Signal Exit | The exit signal fired this bar. |
| Stop Loss | Close price dropped below `enter_price × (1 − Stop Loss)`. |
| Take Profit | Close price rose above `enter_price × (1 + Take Profit)`. |
| Max Hold | Position has been open for Max Hold Time bars. |

Stop Loss, Take Profit, and Max Hold are evaluated on the current bar's close. The four exit-reason counts are reported separately in the results — see [../results.md](../results.md).

## Reported metrics

The backtest only computes and reports the metrics listed in the schema's `metrics` field. Available metrics:

| Metric | What it means |
|---|---|
| Sharpe | The Sharpe ratio of the equity curve's hourly log returns. |
| Excess Sharpe | Strategy Sharpe minus the Sharpe ratio of the underlying Bitcoin close-price hourly log returns over the same window. Positive = the strategy beat buy-and-hold. Often used as the optimization target. |
| Max Drawdown | Largest peak-to-trough decline of the equity curve, as a fraction (0.2 = a 20% drop). |
| Mean Hold Time | Average position duration in bars (hours). |
| Std Hold Time | Standard deviation of position durations. |
| Total Entries | Number of positions opened. |
| Total Exits | Number of positions closed. |
| Signal / Stop Loss / Take Profit / Max Hold Exits | Breakdown of the four exit reasons. |

Alongside the metrics, each split's results include an `equity_curve`: the equity series over time, downsampled to at most 100 equally spaced points (for charting).

**Is Invalid** is reported separately (not a selectable metric): true if equity ever went negative, or if zero positions were ever closed. When invalid, every requested metric is forced to 0.

## Why "excess" Sharpe?

Bitcoin's raw Sharpe over a bull market window can be quite high just from holding. A strategy that produced 0.8 Sharpe in a window where buy-and-hold produced 0.9 actually underperformed and should not be rewarded. Subtracting the benchmark forces the search to find strategies that **add value** over holding, not strategies that look good only because the market was up.

## Why Is Invalid matters

Two failure modes get scored as zero (so the search ignores them):

- **Negative equity** — the strategy went bust during the window.
- **Zero exits** — the strategy never closed a position. This catches degenerate strategies whose entry signal never fires, or whose exit signal never fires (so positions accumulate and equity reflects only paper gains).

Both produce the same Is Invalid = true result.
