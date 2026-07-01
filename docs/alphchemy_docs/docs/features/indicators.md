# Indicator types

Every feature type, what it computes, and the fields you fill in.

- `i` denotes the `i`th bar from the start
- `close[i]` denotes

Every feature has a **Feature ID** field — your unique short name for it. The tables below only list each feature's additional fields.

## Constant

A fixed value, the same on every bar.

| Field | Meaning |
|---|---|
| Constant | Value to return on every bar |

## Raw Returns

Bar-over-bar price return. 

| Field | Meaning |
|---|---|
| `returns` | `log` → `ln(price[i] / price[i-1])`. `simple` → ``. |
| `ohlc` | which OHLC to use |

Log return: `ln(price[i] / price[i-1])`
Simple return: `(price[i] / price[i-1]) − 1`

The value for first bar is 0.

## Normalized SMA

The close price relative to its simple moving average.

| Field | Meaning |
|---|---|
| window | lookback length |
| ohlc | which OHLC to use |

Value: `sma(prices[i], window) / price[i]`

## Normalized EMA

The close price relative to its exponential moving average.

| Field | Meaning |
|---|---|
| ohlc | Which price stream to use. |
| Window | look length |
| Smooth Factor | smoothing factor for ema |

Value: `ema(price, window, smooth) / price[i]`.

## Normalized MACD

The Moving Average Convergence/Divergence indicator, normalized by close.

| Field | Meaning |
|---|---|
| ohlc | Which price stream to use. |
| Fast Window | Lookback length for the fast EMA. |
| Fast Smooth Factor | Smoothing factor for the fast EMA. |
| Slow Window | Lookback for the slow EMA. Must be ≥ Fast Window. |
| Slow Smooth Factor | Smoothing factor for the slow EMA. |
| Signal Window | Lookback for the signal-line EMA built off the MACD line. |
| Signal Smooth Factor | Smoothing factor for the signal-line EMA. |
| output | `line` (fast − slow), `signal` (EMA of the line), or `hist` (line − signal). |

Final value is the chosen output divided by close, putting it in a small range around 0.

## RSI

The classic Relative Strength Index, using exponentially smoothed gains and losses.

| Field | Meaning |
|---|---|
| ohlc | Which price stream to use. |
| Window | Lookback length. Standard RSI uses 14. |
| Smooth Factor | Smoothing factor for the gains/losses EMA. Standard RSI uses 14. |

Value ranges from 0 to 100. Conventionally, RSI > 70 = overbought, RSI < 30 = oversold.

## Normalized BB (Bollinger Bands)

| Field | Meaning |
|---|---|
| ohlc | Which price stream to use. |
| Window | Lookback length. |
| Standard Deviation Multiplier | How many standard deviations the bands sit from the mean. Standard BB uses 2.0. Must be > 0. |
| output | `upper` (mean + multiplier × std), `lower` (mean − multiplier × std), or `width` (upper − lower). |

Final value is the chosen output divided by close.

## Stochastic

| Field | Meaning |
|---|---|
| Window | Lookback for the rolling high/low range. |
| Smooth Factor | Lookback when output is `percent_d`, used to smooth %K into %D. |
| output | `percent_k` = raw stochastic. `percent_d` = rolling average of %K. |

Value: `100 × (close − rolling_min(low)) / (rolling_max(high) − rolling_min(low))`. Range 0–100.

## Normalized ATR (Average True Range)

| Field | Meaning |
|---|---|
| Window | Lookback for the true-range EMA. |
| Smooth Factor | Smoothing factor for that EMA. |

A volatility measure. Bigger value = more recent volatility relative to price.

## ROC (Rate of Change)

| Field | Meaning |
|---|---|
| ohlc | Which price stream to use. |
| Window | Lookback length. |

Value: `price[i] / price[i − window]`. `> 1.0` means up over the period, `< 1.0` means down. A simple momentum measure.

## Normalized DC (Donchian Channel)

| Field | Meaning |
|---|---|
| Window | Lookback for the rolling high and low. |
| output | `upper` (rolling high), `lower` (rolling low), `middle` (average of the two), or `width` (high − low). |

Final value is the chosen output divided by close.

## Warm-up bars

Many of these features need history to be meaningful: a 20-bar SMA is meaningless on bar 5. For the first **Window** bars (or the longest of the windows for MACD-style features), the feature returns 0. Set the Backtest Schema's **Start Offset** to at least your longest feature window so trading begins only after every feature has warmed up — see [../experiment/backtest.md](../experiment/backtest.md).
