# Overview

An experiment is an automated search for a profitable trading strategy. You define a time range, choose what indicators (features) the strategy can look at, and pick how the strategy decides when to buy and sell. Alphchemy then tries many candidate strategies, simulates each one as if it had been trading historically, and reports the best one along with how well it did.

## What an experiment actually does

1. **Pull historical price data** — hourly Bitcoin candles between the start and end timestamps you provide.
2. **Compute features** — technical indicators (SMA, RSI, Bollinger Bands, etc.) from those prices.
3. **Split the data into folds** — overlapping time windows. Inside each fold, the earliest slice is the **training** window, the middle slice is the **validation** window, and the latest slice is the **test** window. The test window is the one that matters: it is data the strategy never sees during the search.
4. **Search for a strategy** — on the training window, an optimizer tries many candidate strategies, keeps the ones that score well, mutates and recombines them, and repeats. The validation window is used to pick a winner without overfitting to the training window.
5. **Score the winner** — the winning strategy is replayed on the training, validation, and test windows separately. You get a metrics table for each.
6. **Repeat across folds** — the whole search is repeated independently in every fold so you can see whether the result holds up across different time periods or is just a lucky window.

## Two kinds of strategy

You pick one when configuring an experiment:

- **Logic** — the strategy is a small circuit of AND / OR / XOR gates fed by feature-vs-threshold comparisons. See [network/logic_net.md](network/logic_net.md).
- **Decision** — the strategy is a decision tree of feature-vs-threshold branches. See [network/decision_net.md](network/decision_net.md).

Logic and Decision strategies share everything else (folds, backtest simulation, optimizer, scoring).

## Reading order

If you are new, read in this order:

1. [experiment.md](experiment/experiment.md) — the top-level configuration.
2. [features.md](features/features.md) → [features/indicators.md](features/indicators.md) — what the strategy can look at.
3. [network.md](network/network.md) → [network/logic_net.md](network/logic_net.md), [network/decision_net.md](network/decision_net.md) — the two strategy shapes.
4. [actions.md](actions/actions.md) → [actions/logic_actions.md](actions/logic_actions.md), [actions/decision_actions.md](actions/decision_actions.md) — what the optimizer is allowed to build.
5. [optimizer.md](optimizer/optimizer.md) → [optimizer/genetic.md](optimizer/genetic.md) — how the search runs.
6. [experiment/experiment.md](experiment/experiment.md), [experiment/strategy.md](experiment/strategy.md), [experiment/backtest.md](experiment/backtest.md) — how folds, entry/exit rules, and trade simulation work.
7. **[experiment/overfitting.md](experiment/overfitting.md)** — required reading before you trust any result.
8. [results.md](results.md) — what every field in the results means.
