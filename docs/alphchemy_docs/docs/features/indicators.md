# Indicators

This page describes every feature type, its parameters, and what it computes.

Notes:
- `i` denotes the `i`th bar from the start
- `close[i]` denotes the closing price for the `i`th bar
- `prices` denotes an OHLC price stream, selected using the `ohlc` parameter
- `prices[i]` denotes an OHLC price for the `i`th bar

## Constant

A fixed value, the same on every bar.

**Fields:**
- `constant`:
    - description: value for every bar
    - constraints: must be a number

**Format:**
```
<feature id>:
  feature: constant
  constant: ...
```

**Example:**
```
constant_1:
  feature: constant
  constant: 1.0
```

## Raw Returns

Bar-over-bar price return.

**Fields:**
- `returns_type`:
    - calculation:
      - log: `ln(prices[i] / prices[i - 1])`
      - simple: `(prices[i] / prices[i - 1]) - 1`
    - constraints: must be `log` or `simple`
- `ohlc`:
    - description: which OHLC price stream to use
    - constraints: must be `open`, `high`, `low`, or `close`

**Format:**
```
<feature id>:
  feature: raw_returns
  returns_type: ...
  ohlc: ...
```

**Example:**
```
returns_close:
  feature: raw_returns
  returns_type: log
  ohlc: close
```

The value for first bar is 0.

## Normalized SMA

The OHLC price relative to its simple moving average.

**Fields:**
- `window`:
    - description: lookback length
    - constraints: must be integer > 0
- `ohlc`:
    - description: which OHLC price stream to use
    - constraints: must be `open`, `high`, `low`, or `close`

**Format:**
```
<feature id>:
  feature: normalized_sma
  window: ...
  ohlc: ...
```

**Example:**
```
sma_20_norm:
  feature: normalized_sma
  window: 20
  ohlc: close
```

Value: `sma(prices, window)[i] / prices[i]`

## Normalized EMA

The OHLC price relative to its exponential moving average.

**Fields:**
- `window`:
    - description: lookback length
    - constraints: must be integer > 0
- `smooth`:
    - description: smoothing factor for ema
    - constraints: must be integer > 0
- `ohlc`:
    - description: which OHLC price stream to use
    - constraints: must be `open`, `high`, `low`, or `close`

**Format:**
```
<feature id>:
  feature: normalized_ema
  window: ...
  smooth: ...
  ohlc: ...
```

**Example:**
```
ema_20_norm:
  feature: normalized_ema
  window: 20
  smooth: 2
  ohlc: close
```

Value: `ema(prices, window, smooth)[i] / prices[i]`

## Normalized MACD

Moving Average Convergence/Divergence indicator, normalized by OHLC price.

**Fields:**
- `fast_window`:
    - description: lookback length for fast ema
    - constraints: must be integer > 0 and <= `slow_window`
- `fast_smooth`:
    - description: smoothing factor for fast ema
    - constraints: must be integer > 0
- `slow_window`:
    - description: lookback length for slow ema
    - constraints: must be integer > 0
- `slow_smooth`:
    - description: smoothing factor for slow ema
    - constraints: must be integer > 0
- `signal_window`:
    - description: lookback length for the signal ema
    - constraints: must be integer > 0
- `signal_smooth`:
    - description: smoothing factor for the signal ema
    - constraints: must be integer > 0
- `output`:
    - calculation:
      - line: `ema(prices, fast_window, fast_smooth) - ema(prices, slow_window, slow_smooth)`
      - signal: `ema(line, signal_window, signal_smooth)`
      - hist: `line - signal`
    - constraints: must be `line`, `signal`, or `hist`
- `ohlc`:
    - description: which OHLC price stream to use
    - constraints: must be `open`, `high`, `low`, or `close`

**Format:**
```
<feature id>:
  feature: normalized_macd
  fast_window: ...
  fast_smooth: ...
  slow_window: ...
  slow_smooth: ...
  signal_window: ...
  signal_smooth: ...
  output: ...
  ohlc: ...
```

**Example:**
```
macd_hist_norm:
  feature: normalized_macd
  fast_window: 12
  fast_smooth: 2
  slow_window: 26
  slow_smooth: 2
  signal_window: 9
  signal_smooth: 2
  output: hist
  ohlc: close
```

Value: `output / prices[i]`

## RSI

Relative Strength Index

**Fields:**
- `window`:
    - description: lookback length
    - constraints: must be integer > 0
- `smooth`:
    - description: smoothing factor for ema over gains and losses
    - constraints: must be integer > 0
- `ohlc`:
    - description: which OHLC price stream to use
    - constraints: must be `open`, `high`, `low`, or `close`

**Format:**
```
<feature id>:
  feature: rsi
  window: ...
  smooth: ...
  ohlc: ...
```

**Example:**
```
rsi_14:
  feature: rsi
  window: 14
  smooth: 2
  ohlc: close
```

## Normalized BB

Bollinger Bands, normalized by OHLC price

**Fields:**
- `window`:
    - description: lookback length
    - constraints: must be integer > 0
- `std_multiplier`:
    - description: standard deviation multiplier
    - constraints: must be > 0.0
- `output`:
    - calculation:
      - upper: `mean + std_multiplier * std`
      - lower: `mean - std_multiplier * std`
      - width: `2 * std_multiplier * std`
    - constraints: must be `upper`, `lower`, or `width`
- `ohlc`:
    - description: which OHLC price stream to use
    - constraints: must be `open`, `high`, `low`, or `close`

**Format:**
```
<feature id>:
  feature: normalized_bb
  window: ...
  std_multiplier: ...
  output: ...
  ohlc: ...
```

**Example:**
```
bb_upper_20:
  feature: normalized_bb
  window: 20
  std_multiplier: 2.0
  output: upper
  ohlc: close
```

Value: `output / prices[i]`

## Stochastic

**Fields:**
- `window`:
    - description: lookback length
    - constraints: must be integer > 0
- `smooth_window`:
    - description: lookback length for percent_d
    - constraints: must be integer > 0
- `output`:
    - calculation:
      - percent_k: `100 * (close[i] - rolling_min(low, window)[i]) / (rolling_max(high, window)[i] - rolling_min(low, window)[i])`.
      - percent_d: `sma(percent_k, smooth_window)[i]`
    - constraints: must be `percent_k` or `percent_d`

**Format:**
```
<feature id>:
  feature: stochastic
  window: ...
  smooth_window: ...
  output: ...
```

**Example:**
```
stoch_d_14:
  feature: stochastic
  window: 14
  smooth_window: 3
  output: percent_d
```

Value: `output`

## Normalized ATR

**Fields:**
- `window`:
    - description: lookback length
    - constraints: must be integer > 0
- `smooth`:
    - description: smoothing factor for ema over true range
    - constraints: must be integer > 0

**Format:**
```
<feature id>:
  feature: normalized_atr
  window: ...
  smooth: ...
```

**Example:**
```
atr_14_norm:
  feature: normalized_atr
  window: 14
  smooth: 2
```

Value: `ema(true_range, window, smooth)[i] / close[i]`

## ROC

**Fields:**
- `window`:
    - description: lookback length
    - constraints: must be integer > 0
- `ohlc`:
    - description: which OHLC price stream to use
    - constraints: must be `open`, `high`, `low`, or `close`

**Format:**
```
<feature id>:
  feature: roc
  window: ...
  ohlc: ...
```

**Example:**
```
roc_12:
  feature: roc
  window: 12
  ohlc: close
```

Value: `prices[i] / prices[i - window]`

## Normalized DC

**Fields:**
- `window`:
    - description: lookback length
    - constraints: must be integer > 0
- `output`:
    - calculation:
      - upper: `rolling_max(high, window)[i]`
      - lower: `rolling_min(low, window)[i]`
      - middle: `(upper + lower) / 2`
      - width: `upper - lower`
    - constraints: must be `upper`, `lower`, `middle`, or `width`

**Format:**
```
<feature id>:
  feature: normalized_dc
  window: ...
  output: ...
```

**Example:**
```
dc_middle_20:
  feature: normalized_dc
  window: 20
  output: middle
```

Value: `output / close[i]`

## Further reading

- experiment/backtest: Indicators need history to be meaningful. The Backtest Schema's `start_offset` parameter allows indicators to warm up before their outputs are used before trading.
