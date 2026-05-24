# Actions

The **Actions** node tells the search what it is allowed to do when building and mutating candidate networks. You don't pick the mutations yourself — the search does — but you control:

- which features can be picked from, and in what order
- how many threshold values to try (a discrete grid between min and max)
- which gate types or tree node types are allowed
- whether feedback wiring (Logic) or reference nodes (Decision) are permitted
- any *meta actions* — named macros that chain several primitive operations into one

You add either a **Logic Actions** child or a **Decision Actions** child under your Strategy, matching whichever kind of Base Network you chose.

## Why this matters

Every candidate strategy is built by taking the Base Network and applying a chain of operations. The more permissive the actions, the larger the search space — and the more capacity to overfit.

Constraining actions is one of your levers against overfitting:

- Smaller threshold-grid resolution = coarser threshold steps = less freedom to fit noise.
- Fewer features = less freedom.
- Disallowing recurrence (Logic) or references (Decision) = strictly simpler shapes.

See [experiment/overfitting.md](../experiment/overfitting.md).

## Concepts shared by both Actions kinds

### Thresholds

For every feature you list, you also declare a min–max range for thresholds via **Threshold** children under your Actions node. The range is discretized into evenly-spaced values, and threshold-setting operations pick from that grid.

Each Threshold node has these fields:

| Field | Meaning |
|---|---|
| Feature ID | Must match a Feature ID under your Strategy. Every feature must have exactly one Threshold node. |
| Min | Lower end of the threshold range. |
| Max | Upper end. Must be > Min. |

Pick threshold ranges that match the natural range of each feature:

| Feature kind | Suggested range |
|---|---|
| RSI / Stochastic | 0 to 100 |
| Normalized SMA / EMA / BB / DC | 0.9 to 1.1 (feature is around 1.0) |
| ROC | 0.95 to 1.05 |
| Constant feature with value 1.0 | 0.5 to 1.5 |

### Feature Order

A comma-separated list of every Feature ID in the order the search cycles through them when picking a feature. Must contain every Feature ID exactly once. The order matters less than which features are present.

### # Of Threshold Choices

How many evenly-spaced values to discretize each feature's threshold range into. Must be > 0.

| Value | Effect |
|---|---|
| ~5 | Coarse grid. Faster search, more robust strategies. |
| ~10 | Sensible default. |
| ~20 | Fine grid. More precise but more overfitting risk. |

### Meta Actions

A **Meta Action** is a named macro that, when triggered, runs a sequence of primitive operations in order. They let you teach the search common operation chains so a single random choice can build a meaningful sub-structure.

Each Meta Action node has these fields:

| Field | Meaning |
|---|---|
| Label | Name of the macro. |
| Sub Actions | Comma-separated list of primitive operations to run in order. |

You don't have to add any Meta Actions — none is fine. They are an advanced lever.

## Primitive actions

A **primitive action** is one of the small built-in operations the search can perform on a candidate network. On every step of building a candidate, the search picks one primitive (or one Meta Action, which expands into a chain of primitives) and applies it. The list below is the complete vocabulary; Meta Actions you define in the Sub Actions field reference these by name.

Primitives split into three categories: cursor moves, setters, and builders. To understand what each one does, it helps to know the cursors the search maintains while building a candidate:

- **Feature cursor** — index into Feature Order, choosing which feature setters refer to.
- **Threshold cursor** — index into the discrete threshold grid (size = # Of Threshold Choices).
- **Node cursor** — index of the "current" node that setters and builders operate on.
- **Selected-node cursor** — a second node index, used as the target when wiring connections.
- **Extra cursor** — Logic only, indexes into Allowed Gates.

All cursors wrap around, so a `next_*` action that runs past the end starts back at 0.

### Cursor-move actions

| Name | What it does | Logic | Decision |
|---|---|---|---|
| `next_feat` | Advance the feature cursor by 1. | ✓ | ✓ |
| `next_threshold` | Advance the threshold cursor by 1. | ✓ | ✓ |
| `next_node` | Advance the node cursor by 1. | ✓ | ✓ |
| `select_node` | Copy node cursor → selected-node cursor. Use before a `set_*idx` action so the connection targets the right node. | ✓ | ✓ |
| `next_gate` | Advance the extra cursor through Allowed Gates. | ✓ | — |

### Setter actions

Each setter writes into the node currently under the node cursor.

| Name | What it does | Logic | Decision |
|---|---|---|---|
| `set_feat` | Write the feature at the feature cursor into the current node's Feature ID. Applies to Input Nodes (Logic) and Branch Nodes (Decision). | ✓ | ✓ |
| `set_threshold` | Compute the threshold for the current feature + threshold cursor and write it into the current node's Threshold. | ✓ | ✓ |
| `set_gate` | Write the gate at the extra cursor into the current Gate Node's Gate field. | ✓ | — |
| `set_in1_idx` | Wire the current Gate Node's in1 input to the selected-node index. Skipped when Allow Recurrence is off and the selected index is ≥ the node cursor. | ✓ | — |
| `set_in2_idx` | Same as `set_in1_idx`, but for in2. | ✓ | — |
| `set_true_idx` | Wire the current node's True Node Index to the selected-node index. | — | ✓ |
| `set_false_idx` | Wire the current node's False Node Index to the selected-node index. | — | ✓ |
| `set_ref_idx` | Wire the current Reference Node's Reference Node Index to the selected-node index. | — | ✓ |

### Builder actions

Each builder appends one new blank node to the network.

| Name | What it does | Logic | Decision |
|---|---|---|---|
| `new_input` | Append a blank Input Node. | ✓ | — |
| `new_gate` | Append a blank Gate Node. | ✓ | — |
| `new_branch` | Append a blank Branch Node. | — | ✓ |
| `new_ref` | Append a blank Reference Node. Skipped when Allow References is off. | — | ✓ |

Setters silently no-op when the current node is the wrong kind (e.g. `set_gate` while the node cursor is on an Input Node). A stray primitive in a Meta Action is harmless but wasted.

## The two Actions kinds

- [actions/logic_actions.md](logic_actions.md) — for Logic Networks
- [actions/decision_actions.md](decision_actions.md) — for Decision Networks
