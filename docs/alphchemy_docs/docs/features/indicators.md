# Indicators

Every feature type, what it computes, and the fields you fill in.

- `i` denotes the `i`th bar from the start
- `close[i]` denotes the closing price for the `i`th bar
- `prices` denotes an OHLC price stream, selected using the `ohlc` parameter
- `prices[i]` denotes an OHLC price for the `i`th bar

## Constant

A fixed value, the same on every bar.

| Field | Meaning |
|---|---|
| constant | value for every bar |

## Raw Returns

Bar-over-bar price return. 

| Field | Meaning |
|---|---|
| returns_type | log: `ln(prices[i] / prices[i - 1])`. simple: `(prices[i] / prices[i - 1]) - 1` |
| ohlc | which OHLC to use |

The value for first bar is 0.

## Normalized SMA

The OHLC price relative to its simple moving average.

| Field | Meaning |
|---|---|
| window | lookback length |
| ohlc | which OHLC to use |

Value: `sma(prices, window)[i] / prices[i]`

## Normalized EMA

The OHLC price relative to its exponential moving average.

| Field | Meaning |
|---|---|
| window | lookback length |
| smooth | smoothing factor for ema |
| ohlc | which OHLC to use |

Value: `ema(prices, window, smooth)[i] / prices[i]`

## Normalized MACD

Moving Average Convergence/Divergence indicator, normalized by OHLC price.

| Field | Meaning |
|---|---|
| fast_window | lookback length for fast ema |
| fast_smooth | smoothing factor for fast ema |
| slow_window | lookback length for slow ema. must be >= fast_window |
| slow_smooth | smoothing factor for slow ema |
| signal_window | lookback length for the signal ema |
| signal_smooth | smoothing factor for the signal ema |
| output | line: `ema(prices, fast_window, fast_smooth) - ema(prices, slow_window, slow_smooth)`, signal: `ema(line, signal_window, signal_smooth)`, or hist: `line - signal` |
| ohlc | which OHLC to use |

Value: `output / prices[i]`

## RSI

Relative Strength Index

| Field | Meaning |
|---|---|
| window | lookback length |
| smooth | smoothing factor for ema over gains and losses |
| ohlc | which OHLC to use |

## Normalized BB

Bollinger Bands, normalized by OHLC price

| Field | Meaning |
|---|---|
| window | lookback length |
| std_multiplier | standard deviation multiplier |
| output | upper: `mean + std_multiplier * std`. lower: `mean - std_multiplier * std`. width: `2 * std_multiplier * std` |
| ohlc | which OHLC to use |

Value: `output / prices[i]`

## Stochastic

| Field | Meaning |
|---|---|
| window | lookback length |
| smooth_window | lookback length for percent_d |
| output | percent_k: `100 * (close[i] - rolling_min(low, window)[i]) / (rolling_max(high, window)[i] - rolling_min(low, window)[i])`. percent_d: `sma(percent_k, smooth_window)[i]` |

Value: `output`

## Normalized ATR (Average True Range)

| Field | Meaning |
|---|---|
| window | lookback length |
| smooth | smoothing factor for ema over true range |

Value: `ema(true_range, window, smooth)[i] / close[i]`

## ROC (Rate of Change)

| Field | Meaning |
|---|---|
| window | lookback length |
| ohlc | which OHLC to use |

Value: `prices[i] / prices[i - window]`

## Normalized DC (Donchian Channel)

| Field | Meaning |
|---|---|
| window | lookback length |
| output | upper: `rolling_max(high, window)[i]`. lower: `rolling_min(low, window)[i]`. middle: `(upper + lower) / 2`. width: `upper - lower` |

Value: `output / close[i]`

## Warm-up bars

Many of these features need history to be meaningful: a 20-bar SMA is meaningless on bar 5. For the first `window` bars (or the longest of the windows for MACD-style features), the feature returns 0. Set the Backtest Schema's **Start Offset** to at least your longest feature window so trading begins only after every feature has warmed up — see [../experiment/backtest.md](../experiment/backtest.md).
