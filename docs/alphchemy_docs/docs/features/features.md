# Features

A **feature** is a number derived from the price history that the strategy can compare against thresholds. Every feature produces one value per bar, from the start of the data to the end.

The strategy sees only features — it never sees raw OHLC directly. So the choice of which features to include is the most important choice you make for an experiment, before any search knob.

## How you add features

Under your Strategy node, the **Features** slot accepts one node per feature you want the search to be able to use. The available feature types are listed in [features/indicators.md](indicators.md). You can add as many as you want, and you can include multiple instances of the same type with different settings (e.g. one SMA with Window = 20 and another with Window = 50).

## Field that every feature has

| Field | Meaning |
|---|---|
| Feature ID | A unique short name you give this feature (letters, digits, underscores). Must be unique across all features in the Strategy. Other nodes that reference features — Input Node, Branch Node, Threshold ranges — use this ID. |

Most features also take an **ohlc** dropdown choosing which price stream to compute from (Open / High / Low / Close) and one or more **Window** fields giving lookback length in bars (hours).

## Normalization

Every feature is normalized so its values fall in a comparable range — usually a small ratio around 1.0 (for moving-average-based features) or 0–100 (for RSI / Stochastic). This means thresholds on different features sit in known ranges, and the same threshold-grid settings can be reused without manual scaling.

## Picking features

Fewer features is almost always better. Each extra feature is one more dimension the search can fit noise in.

A reasonable starting set:

| Role | Suggestion |
|---|---|
| Trend-following | Normalized SMA, window 20 |
| Mean-reversion | RSI, window 14 |
| Volatility | Normalized ATR or Normalized BB Width |

That gives the search enough to build a reasonable strategy without overwhelming it. Add more only if you have a specific reason.

You can also add a Constant feature with a known value (e.g. 1.0) if you want the search to have a fixed baseline available.

See [features/indicators.md](indicators.md) for every feature type and its fields.
