# Decision Network

A Decision Network is a tree of nodes. Starting at node 0, each node is evaluated, its true/false result decides which child node to evaluate next, and so on. The path of visited nodes is called the **trail**. Entry and Exit rules use Node Pointers to read positions in that trail.

There are two kinds of node you can add under it: **Branch Node** and **Reference Node** (often shortened to "ref node").

- A Branch Node compares one feature against a threshold. Result is true when `feature[i] > threshold`.
- A Reference Node reads the value of some other node already evaluated, and uses it as this node's result. Useful for reusing sub-results.

Both kinds carry a true-child and a false-child pointer; the value picks which child the trail walks into next.

## Decision Network fields

| Field | Meaning |
|---|---|
| Max Trail Length | Maximum number of nodes the trail may visit on one bar. Acts as a safety cap so badly-wired networks (with loops) can't run forever. Must be > 0. Typical: 16–32. |
| Default Value | Boolean used when no value is available (warm-up, dangling pointer). Almost always `false`. |

Children: one **Nodes** slot containing any mix of Branch Nodes and Reference Nodes.

## Branch Node fields

| Field | Meaning |
|---|---|
| Feature ID | Which feature this node compares against. Optional. |
| Threshold | Cutoff value. Node is true when `feature[i] > threshold`. Optional. |
| True Node Index | Which node the trail walks into when this node is true. Blank = trail ends here (this is a *leaf*). |
| False Node Index | Which node the trail walks into when this node is false. Blank = leaf. |

## Reference Node fields

| Field | Meaning |
|---|---|
| Reference Node Index | Index of the node whose current value this Reference Node copies. Optional. |
| True Node Index | Same as Branch. |
| False Node Index | Same as Branch. |

Reference Nodes let you reuse the result of an earlier Branch without recomputing it. The search can only create them if **Allow References** is on for the Decision Actions node — see [../actions/decision_actions.md](../actions/decision_actions.md).

All node-index fields must be less than the number of nodes in the network.

## Decision Penalties

All values must be ≥ 0.

| Field | What it counts |
|---|---|
| Node Penalty | Once per node. The basic complexity tax. |
| Branch Node Penalty | Extra per Branch Node. |
| Reference Node Penalty | Extra per Reference Node. |
| Leaf Node Penalty | Charged per child pointer (true / false) that is missing — i.e. for each leaf edge. Encourages building deeper, more complete trees. |
| Non-leaf Node Penalty | Charged per child pointer that is present. Discourages deep trees. |
| Used Feature Penalty | Once per *distinct* feature referenced by any Branch Node. |
| Unused Feature Penalty | Once per feature in the Features slot not referenced by any Branch Node. |

### Sensible starting values

| Field | Starting value |
|---|---|
| Node Penalty | 0.005 |
| Branch Node Penalty | 0.001 |
| Reference Node Penalty | 0.002 |
| Leaf Node Penalty | 0 |
| Non-leaf Node Penalty | 0 |
| Used Feature Penalty | 0 |
| Unused Feature Penalty | 0 |

A higher Reference Node Penalty than Branch Node Penalty keeps the search from spamming references when a simple branch would do.

If you see overfitting (see [../experiment/overfitting.md](../experiment/overfitting.md)), raise Node Penalty, Branch Node Penalty, and Reference Node Penalty together.

**Leaf Node Penalty** vs **Non-leaf Node Penalty**: only one should be non-zero at a time. They pull in opposite directions.

## How big should the tree be?

Cap things with Max Trail Length, and use the Node / Branch / Reference penalties to bound the breadth. Start with 1–3 nodes and grow only if test results justify it.
