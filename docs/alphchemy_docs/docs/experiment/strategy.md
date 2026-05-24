# Strategy

The **Strategy** node bundles everything the search needs and uses to trade. Under it you add child nodes covering features, the network, the search settings, and trading rules.

## Strategy field

| Field | Meaning |
|---|---|
| Global Max Positions | Cap on the total number of open positions across **all** entry rules combined. Must be > 0. |

## Children of Strategy

| Child slot | What to put there |
|---|---|
| Base Network | One Logic Network or one Decision Network — see [../network/network.md](../network/network.md). |
| Features | One feature node per indicator you want the strategy to be able to look at — see [../features/features.md](../features/features.md). |
| Actions | One Logic Actions or Decision Actions node, matching your Base Network — see [../actions/actions.md](../actions/actions.md). |
| Penalties | One Logic Penalties or Decision Penalties node, matching your Base Network. |
| Stop Conditions | When the search ends — see [../optimizer/optimizer.md](../optimizer/optimizer.md). |
| Optimizer | Search engine settings — see [../optimizer/genetic.md](../optimizer/genetic.md). |
| Entry | One or more Entry nodes. |
| Exit | One or more Exit nodes. |

## Entry node

An Entry rule says "when this part of the network reports true, open a position of this size, up to this many at once."

| Field | Meaning |
|---|---|
| ID | Unique name for this Entry rule. Used by Exit rules to refer to it. Letters, digits, and underscores only. |
| Qty | How many units of Bitcoin to buy per position. Must be > 0. |
| Max Positions | Cap on simultaneous open positions from **this** Entry rule. Must be > 0. |

Under each Entry node, add a **Node Pointer** child that picks which network node produces this rule's signal.

## Exit node

An Exit rule says "when this part of the network reports true, close positions opened by these Entry rules. Also enforce stop-loss, take-profit, and max-hold for those positions."

| Field | Meaning |
|---|---|
| ID | Unique name for this Exit rule. |
| Entry Schemas | Comma-separated list of Entry IDs this Exit applies to. Must be non-empty and only contain IDs that exist on Entry nodes. |
| Stop Loss | Fractional drop from entry price that force-closes the position. 0.05 = 5%. Must be > 0. |
| Take Profit | Fractional rise from entry price that force-closes the position. 0.10 = 10%. Must be > 0. |
| Max Holding Time | Maximum bars (hours) a position from these Entry rules may stay open. Must be > 0. |

Under each Exit node, add a **Node Pointer** child that picks which network node produces this rule's signal.

A position is closed by the **first** of these to trigger on a given bar: matching exit signal, stop loss, take profit, or max hold. See [backtest.md](backtest.md) for the exact evaluation order.

## Node Pointer

Entry and Exit rules each have one **Node Pointer** child that picks which node in the network produces their signal.

| Field | Meaning |
|---|---|
| Anchor | `from_start` (count from the first node) or `from_end` (count from the last node). |
| idx | Offset from the chosen anchor. `from_end` with idx = 0 = "the last node in the network". |

`from_end` is handy because the search may grow the network: a pointer of "the last node" automatically follows whatever the most-recently-added node is.

## Common shapes

- **One Entry, one Exit** — the simplest setup. Network has two output nodes: one entry signal, one exit signal. Most experiments use this.
- **One Entry, multiple Exits** — useful when you want different stop-loss / take-profit profiles depending on which network condition fires. Each Exit lists the same single Entry ID.
- **Multiple Entries** — typically only useful when you want different position sizes for different signal strengths. Increases search complexity significantly; not recommended unless you have a clear thesis.
