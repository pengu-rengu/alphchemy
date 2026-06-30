# Overfitting

**This is the most important section in the entire docs.** If you skip it, every result you produce will be misleading.

## What overfitting means here

Overfitting is when the search finds a strategy that looks great on the training window because it memorized random quirks of that specific stretch of price history — quirks that won't repeat. As soon as you run that strategy on unseen data, it falls apart.

The classic symptom looks like this:

| Window | Excess Sharpe |
|---|---|
| Training | +0.65 |
| Validation | +0.12 |
| **Test** | **−0.20** |

The search is enthusiastic on training, less so on validation, and the test result is honest: the strategy is worse than nothing.

## Why experiments are unusually prone to it

Three things conspire to make overfitting easy:

1. **Flexible network**: the search can wire up arbitrary combinations of feature comparisons and gates / branches. There are millions of possible networks even for small sizes.
2. **Direct fitting to the objectives**: the search is maximizing the weighted sum of objective metrics on the training window. Anything that bumps that number is rewarded, including coincidences.
3. **Many generations**: the longer the search runs, the more likely it stumbles onto something that exploits a quirk.

A neural network on a fixed architecture has a known parameter count, so you can estimate how much data you need. Here, the effective "parameter count" is whatever the search happens to build. It can balloon under your control if you let it.

## What protects against it

Several safeguards are built in. Use them all.

### 1. Train / validation / test split

Every fold splits its bars into training, validation, test, in that order — see [experiment.md](experiment.md). The search **never sees** the test window. The validation window is used to pick the winner without overfitting to training, and to decide when to stop searching.

If you ever find yourself rerunning the same experiment and tweaking until the test number improves, you are now overfitting to the test set too. Pick a configuration up front and live with whatever it produces.

### 2. Walk-forward folds

One fold = one test result, which could be luck. Five folds = five independent test results. If they all agree the strategy works, that is strong evidence. If they disagree, you do not have a working strategy. Set CV Folds on the Experiment node accordingly.

### 3. Validation-based early stopping

On the Stop Conditions node, **Validation Patience** is the number of iterations the search waits without improvement before giving up. This prevents the search from grinding on long after it has stopped finding genuinely better strategies. Tighter Validation Patience = less overfitting risk, at the cost of possibly stopping too early. See [../optimizer/optimizer.md](../optimizer/optimizer.md).

### 4. Complexity penalties

Each candidate's score has a penalty subtracted that grows with how complex the network is — number of nodes, number of features used, etc. The Penalties node on your Strategy controls these. See [../network/logic_net.md](../network/logic_net.md) and [../network/decision_net.md](../network/decision_net.md). Higher penalties push the search toward simple, robust networks.

Start with small non-zero penalties (e.g. Node Penalty around 0.005). If you see training >> test, raise them. If the search can't find anything interesting, lower them.

### 5. Excess Sharpe as an objective (not raw Sharpe)

Weighting Excess Sharpe — equity Sharpe minus buy-and-hold Sharpe (see [backtest.md](backtest.md)) — in your objectives, rather than raw Sharpe, automatically penalizes strategies that look profitable only because Bitcoin went up during the window.

### 6. The Is Invalid filter

Strategies that go broke or never trade get a score of 0, so the search can't be fooled by degenerate edge cases.

## How to spot overfitting on the results page

Use the four charts and the metrics table together. The big tells:

| Signal | What it means |
|---|---|
| Training ≫ Validation ≫ Test on Excess Sharpe | The clearest signal. If training is +0.6, validation is +0.1, test is −0.1, the result is not a real strategy. |
| Validation ≫ Test | Subtler. Means early stopping picked a sequence that happened to score well on validation by chance. Tighten Validation Patience, raise penalties, or add more CV Folds. |
| Best Training Sequence very different from Best Validation Sequence | They are different sequences — that is expected. But if validation's best sequence appears late in the training history and is wildly different in length or shape, the search may have been chasing noise. |
| Many more Training Improvements than Validation Improvements | Healthy: training and validation improve together. Overfit: training keeps creeping up, validation flatlines early. |
| Exit-reason mix changes drastically across training / validation / test | If training is dominated by take-profit exits but test is dominated by stop-loss exits, the strategy's behavior is regime-dependent and is unlikely to be robust. |
| Test results inconsistent across folds | Some folds positive, others very negative. The average might look fine but no individual market regime gave a reliable result. |

## Knobs to fight overfitting

If you see any of the above, try (in this order):

1. **Raise complexity penalties** on the Penalties node — Node Penalty, Input/Branch penalties, Used/Unused Feature penalties. This is the single biggest lever.
2. **Reduce Sequence Length** on the Optimizer node so candidates are allowed to build smaller networks.
3. **Reduce Max Iterations** and tighten Validation Patience on the Stop Conditions node so the search has less time to find spurious patterns.
4. **Increase CV Folds** on the Experiment node so you need agreement across more test windows.
5. **Reduce the number of Feature nodes** on the Strategy. Fewer features = fewer chances to fit noise.
6. **Use a smaller Base Network** as the starting point, especially for Decision strategies — start with one branch, not ten.

## What "good enough" looks like

A trustworthy result usually has:

- Test Excess Sharpe positive (even if small) on **most** folds.
- Test ≈ Validation ≈ Training within a reasonable spread (the test number should be lower than training, but not by much).
- Comparable exit-reason mixes across training / validation / test.
- A winning sequence that's not absurdly long for the problem.

A modest, consistent edge across folds is far more valuable than a huge edge on one fold and noise everywhere else.
