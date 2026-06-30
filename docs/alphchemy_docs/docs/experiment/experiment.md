# Experiment

The **Experiment** node sits at the root of the tree. Its fields control the time range of historical data and how that range is split for training, validation, and out-of-sample testing. Under it you add a **Backtest Schema** child and a **Strategy** child that hold everything else.

## Fields

| Field | Meaning |
|---|---|
| Validation Size | Fraction of each fold used for the validation window. Typical: 0.1–0.2. Must be > 0 and < 1. |
| Test Size | Fraction of each fold used for the test (out-of-sample) window. Typical: 0.1–0.2. Validation Size + Test Size must be < 1. |
| CV Folds | Number of overlapping folds. More folds = more independent confirmations the strategy generalizes, but the search runs that many times longer. Typical: 3–10. Must be > 0. |
| Fold Size | Length of each fold as a fraction of the full data range. With Fold Size = 0.3 and CV Folds = 5, each fold covers 30% of the data and the five folds tile across the timeline with overlap. Must be > 0 and ≤ 1. |
| Start Timestamp | Inclusive start of the historical data range. |
| End Timestamp | Inclusive end. Must be after Start Timestamp. |

The training window inside each fold is whatever is left after validation and test: `train = 1 − Validation Size − Test Size`. Train, validation, and test are contiguous in that order (train first, validation in the middle, test at the end).

## Children

| Child | Purpose |
|---|---|
| Backtest Schema | Trading simulation settings — see [backtest.md](backtest.md). |
| Strategy | Features, network, optimizer, entry/exit rules — see [strategy.md](strategy.md). |

## Folds

A **fold** is one slice of the timeline carved into three contiguous pieces: training, validation, test. The full search-and-score cycle runs once per fold. CV Folds and Fold Size (above) control how many folds and how big each one is.

### How folds are cut

Given CV Folds = N, Fold Size = F, and a total of L bars of historical data:

- Each fold covers `F × L` bars.
- The first fold starts at bar 0. The last fold ends at the final bar. The folds in between are spaced evenly so they tile the timeline with overlap.
- Inside every fold, the bars are split into training first, then validation, then test, in chronological order. The fractions are set by Validation Size and Test Size.

Example with CV Folds = 5, Fold Size = 0.3, Validation Size = 0.1, Test Size = 0.1 on a 4-year dataset:

| Item | Result |
|---|---|
| Length of each fold | ~14 months |
| Spacing between fold starts | ~9 months |
| Training window per fold | ~11 months |
| Validation window per fold | ~1.4 months |
| Test window per fold | ~1.4 months |

Folds overlap on purpose. You are not trying to reuse data — you are trying to evaluate the same kind of strategy on multiple, *different* test windows. If all five test windows agree the strategy works, that is a much stronger signal than one good test result.

### What happens inside one fold

1. The search runs on the training window only — see [../optimizer/optimizer.md](../optimizer/optimizer.md).
2. While running, each candidate is also scored on the validation window. The system tracks both the best-on-training candidate and the best-on-validation candidate.
3. When the search stops, the **best-on-validation** candidate is taken as the winner.
4. That winner is re-simulated against the training, validation, and test windows separately. Each simulation produces a metric block — see [backtest.md](backtest.md).

The reported objective metrics on the **test** window are the honest answer to "does this strategy work?". Training and validation numbers are useful only as overfitting diagnostics.

## Picking fold settings

The whole point of multiple folds is to find out whether your strategy works across different market regimes, not just one lucky stretch.

- If CV Folds = 1, you only learn whether the strategy works in one window. Avoid.
- If your data range covers many regimes (bull, bear, chop), bigger CV Folds and smaller Fold Size is better.
- If your data range is short, you can use larger Fold Size so each fold has enough data to learn from, but accept that the folds will overlap heavily.

| CV Folds | When to use |
|---|---|
| 1 | Never. One test window cannot tell you whether the result is luck. |
| 3–5 | Typical. Gives a few independent confirmations without making the search prohibitively slow. |
| 10+ | Useful for a final sanity check on a candidate strategy you already trust, since the runtime multiplies accordingly. |

If your test scores are wildly inconsistent across folds (some big positive, others negative), that **is** the answer: the strategy doesn't generalize. Tighten complexity penalties or simplify the network before retrying.

See [overfitting.md](overfitting.md) for how fold settings interact with overfitting.

## Submodule docs

- [backtest.md](backtest.md) — how trades are simulated, what the metrics mean.
- [strategy.md](strategy.md) — entry / exit rules, position sizing, risk caps.
- [overfitting.md](overfitting.md) — the single most important section.
