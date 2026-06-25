# Strategy

The **Strategy** bundles everything the search needs and uses to trade: the network the optimizer evolves, the features it can read, the search settings, and the trading rules. At most **one position** is open at any time — there are no position-count limits and no multiple entry/exit rules.

## Strategy fields

| Field | Meaning |
|---|---|
| Entry Pointer | A **Node Pointer** into the network. When the pointed-to node outputs true and no position is open, a position is opened. |
| Exit Pointer | A **Node Pointer** into the network. When the pointed-to node outputs true, the open position is closed. |
| Stop Loss | Fractional drop from entry price that force-closes the position. 0.05 = 5%. Must be > 0. |
| Take Profit | Fractional rise from entry price that force-closes the position. 0.10 = 10%. Must be > 0. |
| Max Hold Time | Maximum bars (hours) the position may stay open before a forced exit. Must be > 0. |
| Qty | How many units of Bitcoin to buy when a position is opened. Must be > 0. |

The position is closed by the **first** of these to trigger on a given bar: the exit signal, stop loss, take profit, or max hold. See [backtest.md](backtest.md) for the exact evaluation order.

## Children of Strategy

| Child slot | What to put there |
|---|---|
| Base Network | One Logic Network or one Decision Network — see [../network/network.md](../network/network.md). |
| Features | One feature node per indicator you want the strategy to be able to look at — see [../features/features.md](../features/features.md). |
| Actions | One Logic Actions or Decision Actions node, matching your Base Network — see [../actions/actions.md](../actions/actions.md). |
| Penalties | One Logic Penalties or Decision Penalties node, matching your Base Network. |
| Stop Conditions | When the search ends — see [../optimizer/optimizer.md](../optimizer/optimizer.md). |
| Optimizer | Search engine settings — see [../optimizer/genetic.md](../optimizer/genetic.md). |

## Node Pointer

The Entry Pointer and Exit Pointer each pick which node in the network produces their signal.

| Field | Meaning |
|---|---|
| Anchor | `from_start` (count from the first node) or `from_end` (count from the last node). |
| idx | Offset from the chosen anchor. `from_end` with idx = 0 = "the last node in the network". |

`from_end` is handy because the search may grow the network: a pointer of "the last node" automatically follows whatever the most-recently-added node is.
