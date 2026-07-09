# Features

This page describes **features**, which are values computed from OHLC bars.

Every feature produces one value per bar, from start to end.

Every feature has an ID, which is a short name that must be unique across all features in a **strategy**.

**Format:**

```
<id>:
  ...
```

**Example:**

```
rsi_14:
  feature: rsi
  window: 14
  smooth: 2
  ohlc: close
ema_20:
  feature: normalized_ema
  window: 20
  smooth: 2
  ohlc: close
```

## Normalization

Some features are divided by the OHLC prices they were computed with, resulting in small ratios around 1.0.

## Further reading

- features/indicators: All available indicators, along with their parameters and outputs
