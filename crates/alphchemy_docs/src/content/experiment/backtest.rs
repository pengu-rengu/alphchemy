pub const BACKTEST: &str = r####"# Backtest

This page describes **backtests**, which replay one strategy against one price window and report trading metrics.

Each fold produces three backtests: one for training, one for validation, and one for test.

## Backtest Schema

**Fields:**
- `start_offset`:
    - description: number of initial bars to skip before trading
    - constraints: must be integer >= 0
- `start_balance`:
    - description: starting cash balance
    - constraints: must be > 0.0
- `delay`:
    - description: number of bars between signal evaluation and trade execution
    - constraints: must be integer >= 0
- `metrics`:
    - description: metrics to compute and report
    - constraints: each value must be a valid metric name

**Format:**
```
backtest_schema:
  start_offset: ...
  start_balance: ...
  delay: ...
  metrics: ..., ..., ...
```

**Example:**
```
backtest_schema:
  start_offset: 120
  start_balance: 10000.0
  delay: 1
  metrics: excess_sharpe, sharpe, max_drawdown, total_entries, total_exits
```

## How trades are simulated

At most one position is open at any time. Every bar after `start_offset`, the simulator does three things in order:

1. Close the open position if any exit condition fires.
2. Open a position of `qty` units if no position is open and the entry signal fires.
3. Update equity from cash balance and current position value.

A position opens and closes at the current bar's close price. There are no fees, slippage, or partial fills.

## Exit reasons

**Exit reasons:**
- `signal_exits`:
    - description: position closed because the exit signal fired
- `stop_loss_exits`:
    - description: position closed because close price was below `enter_price * (1.0 - stop_loss)`
- `take_profit_exits`:
    - description: position closed because close price was above `enter_price * (1.0 + take_profit)`
- `max_hold_exits`:
    - description: position closed because position age reached `max_hold_time`

Risk exits are checked before signal exits. A single close can increment more than one risk exit counter when multiple risk conditions are true on the same bar.

## Metrics

The backtest only computes metrics listed in `metrics`.

**Metrics:**
- `sharpe`:
    - description: Sharpe ratio of the equity curve's log returns
- `excess_sharpe`:
    - description: strategy Sharpe minus close-price buy-and-hold Sharpe
- `max_drawdown`:
    - description: largest peak-to-trough equity decline as a fraction
- `mean_hold_time`:
    - description: average position duration in bars
- `std_hold_time`:
    - description: standard deviation of position duration in bars
- `total_entries`:
    - description: number of positions opened
- `total_exits`:
    - description: number of positions closed
- `signal_exits`:
    - description: number of signal exits
- `stop_loss_exits`:
    - description: number of stop loss exits
- `take_profit_exits`:
    - description: number of take profit exits
- `max_hold_exits`:
    - description: number of max hold exits

Each split result also includes `equity_curve`, downsampled to at most 100 points.

`is_invalid` is reported separately. It is `true` if equity ever went negative or zero positions were closed. When `is_invalid` is `true`, every requested metric is forced to `0.0`.

## Excess Sharpe

`excess_sharpe` subtracts buy-and-hold Sharpe from strategy Sharpe over the same window. This rewards strategies that add value over holding, not strategies that only look good because the market went up.

## Further reading

- results: Backtest result object fields
- optimizer/genetic: How metrics are used as objectives
- experiment/strategy: Position sizing and exit thresholds
"####;
