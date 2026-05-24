# Logic Actions

Add this as a child of your Strategy when your Base Network is a Logic Network. See [../network/logic_net.md](../network/logic_net.md).

## Logic Actions fields

| Field | Meaning |
|---|---|
| Feature Order | Comma-separated list of every Feature ID in the order the search cycles through them. Must contain every Feature ID exactly once. |
| # Of Threshold Choices | Threshold-grid resolution per feature. Must be > 0. Typical: 10. |
| Allow Recurrence | If `false`, the search can only wire a gate input to nodes with a *lower* index than the gate itself (forward connections only). If `true`, feedback wiring is allowed. **Recommended: false** unless you have a specific reason. |
| Allowed Gates | Comma-separated subset of `and, or, xor, nand, nor, xnor`. Restricting this shrinks the search space. Most strategies are fine with `and, or`. |

## Children

| Slot | What to put there |
|---|---|
| Meta Actions | Zero or more Meta Action nodes — see [actions.md](actions.md). |
| Thresholds | One Threshold node per feature, with Min/Max bounds. |

## Recommended starting setup

| Field | Starting value |
|---|---|
| Feature Order | All your Feature IDs in any order |
| # Of Threshold Choices | 10 |
| Allow Recurrence | false |
| Allowed Gates | and, or |

Add two Meta Actions to speed up structure-building:

| Meta Action Label | Sub Actions |
|---|---|
| place_input | `new_input, set_feat, set_threshold` |
| place_gate | `new_gate, set_gate, set_in1_idx, next_node, set_in2_idx` |

Add one Threshold child per feature with the suggested ranges from [actions.md](actions.md).
