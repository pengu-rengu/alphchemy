# Decision Actions

Add this as a child of your Strategy when your Base Network is a Decision Network. See [../network/decision_net.md](../network/decision_net.md).

## Decision Actions fields

| Field | Meaning |
|---|---|
| Feature Order | Comma-separated list of every Feature ID in the order the search cycles through them. Must contain every Feature ID exactly once. |
| N Thresholds | Threshold-grid resolution per feature. Must be > 0. Typical: 10. |
| Allow References | If `false`, the search cannot create Reference Nodes (nodes that reuse another node's result). The tree stays purely branch-based. **Recommended: false** unless you specifically want shared sub-results. |

## Children

| Slot | What to put there |
|---|---|
| Meta Actions | Zero or more Meta Action nodes — see [actions.md](actions.md). |
| Thresholds | One Threshold node per feature, with Min/Max bounds. |

## Recommended starting setup

| Field | Starting value |
|---|---|
| Feature Order | All your Feature IDs in any order |
| N Thresholds | 10 |
| Allow References | false |

Add one Meta Action to speed up branch-building:

| Meta Action Label | Sub Actions |
|---|---|
| place_branch | `new_branch, set_feat, set_threshold, set_true_idx, next_node, set_false_idx` |

Add one Threshold child per feature with the suggested ranges from [actions.md](actions.md).

References disabled keeps the tree easier to interpret. One Meta Action helps the search build complete branch nodes in a single step rather than discovering each field by chance.
