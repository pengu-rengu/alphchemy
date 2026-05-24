# Backtest

A backtest replays one strategy against one window of price data and reports how it would have performed. Every fold's results contain three backtests: one against the training window, one against validation, one against test. The trading simulation settings come from the **Backtest Schema** node directly under your Experiment.

## Backtest Schema fields

| Field | Meaning |
|---|---|
| Start Offset | How many bars at the start of each window are skipped before trading is allowed. This gives the indicators time to "warm up" — most rolling indicators are meaningless until they have enough history. Set this to at least the longest indicator window you use. |
| Start Balance | Starting cash, in quote currency (USDT). Must be > 0. |
| Delay | How many bars to wait between a signal and the trade. With Delay = 1, a signal at bar N triggers a trade at bar N+1's close. This models the realistic case where you cannot trade on the same bar you observe the signal. |

## How trades are simulated

Every bar (after Start Offset), the simulator does three things in order:

1. **Check exits first.** Walk every open position. Close any that hit a stop-loss, take-profit, or max-hold-time limit; also close any whose exit signal fired.
2. **Check entries.** Walk every entry rule. If its signal fires, and the open balance and position-count limits permit, open a new position at the current close price.
3. **Mark to market.** Update equity = cash balance + (current close × total open size).

A position is opened at the current bar's close price. It is closed at the current bar's close price on whichever bar the exit fires. There are no fees, slippage, or partial fills in the simulation — be aware your live results will be worse than the backtest.

## Position limits

Two limits cap how many positions can be open at once:

| Limit | Source |
|---|---|
| Per entry rule | The **Max Positions** field on each Entry node. Caps simultaneous open positions from that single rule. |
| Global | The **Global Max Positions** field on the Strategy node. Caps the total across all entry rules combined. |

If either limit is reached, the entry is skipped for that bar. If there isn't enough cash to open a new position at the current close price, the entry is also skipped.

## Exit reasons

A position can be closed for four reasons:

| Reason | Triggered when |
|---|---|
| Signal Exit | The matching Exit rule's signal fired this bar. |
| Stop Loss | Close price dropped below `enter_price × (1 − Stop Loss)`. |
| Take Profit | Close price rose above `enter_price × (1 + Take Profit)`. |
| Max Hold | Position has been open for Max Holding Time bars. |

Stop Loss, Take Profit, and Max Hold are evaluated on the current bar's close. The four exit-reason counts are reported separately in the results — see [../results.md](../results.md).

## Reported metrics

After the backtest finishes:

| Metric | What it means |
|---|---|
| Excess Sharpe | The Sharpe ratio of the equity curve's hourly log returns, minus the Sharpe ratio of the underlying Bitcoin close-price hourly log returns over the same window. Positive = the strategy beat buy-and-hold. This is what the search maximizes. |
| Mean Hold Time | Average position duration in bars (hours). |
| Std Hold Time | Standard deviation of position durations. |
| Entries | Number of positions opened. |
| Total Exits | Number of positions closed. |
| Signal / Stop Loss / Take Profit / Max Hold Exits | Breakdown of the four exit reasons. |
| Is Invalid | True if equity ever went negative, or if zero positions were ever closed. When invalid, Excess Sharpe is forced to 0. |

## Why "excess" Sharpe?

Bitcoin's raw Sharpe over a bull market window can be quite high just from holding. A strategy that produced 0.8 Sharpe in a window where buy-and-hold produced 0.9 actually underperformed and should not be rewarded. Subtracting the benchmark forces the search to find strategies that **add value** over holding, not strategies that look good only because the market was up.

## Why Is Invalid matters

Two failure modes get scored as zero (so the search ignores them):

- **Negative equity** — the strategy went bust during the window.
- **Zero exits** — the strategy never closed a position. This catches degenerate strategies whose entry signal never fires, or whose exit signal never fires (so positions accumulate and equity reflects only paper gains).

Both produce the same Is Invalid = true result.
