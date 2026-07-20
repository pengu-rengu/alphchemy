pub const ACTIONS: &str = r####"# Actions

This page describes **actions**, which configure the building blocks the **optimizer** can use to construct candidate **networks**, and how those building blocks can be used.

**Actions** determine:
- which features can be picked
- what threshold values can be picked for each feature
- what kind of connections can be wired between nodes

## Thresholds

For every feature in the **strategy**, you must also have a min-max range for the threshold it is compared against.

The range is discretized into evenly-spaced values, which a threshold-setting **action** can then pick from.

Thresholds are set using the `thresholds` parameter.

**Fields:**
- `feat_id`:
    - description: feature id the threshold range is for
    - constraints: must be a strategy feature id
- `min`:
    - description: lower bound of the threshold range
    - constraints: must be a number
- `max`:
    - description: upper bound of the threshold range
    - constraints: must be a number greater than `min`

Threshold ranges should match the natural range of each feature.

| Feature | Output | Default range |
| --- | --- | --- |
| Constant | configured value `c` | `c - 0.5` to `c + 0.5` |
| Raw Returns | log or simple | -0.1 to 0.1 |
| Normalized SMA | any | 0.9 to 1.1 |
| Normalized EMA | any | 0.9 to 1.1 |
| Normalized MACD | line, signal, or histogram | -0.1 to 0.1 |
| RSI | any | 0 to 100 |
| Normalized BB | upper or lower | 0.9 to 1.1 |
| Normalized BB | width | 0 to 0.2 |
| Stochastic | percent K or percent D | 0 to 100 |
| Normalized ATR | any | 0 to 0.1 |
| ROC | any | 0.9 to 1.1 |
| Normalized DC | upper, lower, or middle | 0.9 to 1.1 |
| Normalized DC | width | 0 to 0.2 |

An omitted `thresholds` block or feature entry uses the feature's full default range. An omitted `min` or `max` field uses the corresponding default bound. Explicit bounds override these defaults.

**Format**
```
<feat_id>:
  min: ...
  max: ...
```

**Example**:
```
rsi_14:
  min: 10
  max: 90
ema_20:
  min: 0.9
  max: 1.1
```

## Number Of Threshold Choices

This determines how many evenly-spaced values to discretize each feature's threshold range into. This is set using the `n_thresholds` parameter.

| Value | Effect |
| --- | --- |
| ~5 | less precise, more robust strategies, and easier to explore all thresholds |
| ~10 | more precise, and harder to explore all thresholds |
| ~20 | most precise, hardest to explore all thresholds, and increased overfitting risk |

## Feature Order

The **actions** configuration has a list of what features can be picked and in what order to cycle them.

Features near the front of the list are easier to reach, because picking them requires fewer `next_feat` actions.

Features near the end of the list are harder to reach, because picking them requires more `next_feat` actions.

The feature order is set using the `feat_order` parameter. When omitted, it defaults to all configured feature ids in declaration order.

## Primitive actions

A **primitive action** is an operation the **optimizer** can perform on a candidate network. On every step of building a candidate, the **optimizer** picks an action and applies it.

Primitives split into three categories: cursor moves, setters, and builders. The **optimizer** maintains the following cursor states when building a candidate network:

- **Feature cursor** — index into the **feature order**, choosing which feature setters refer to.
- **Threshold cursor** — index into the discrete threshold values, choosing which threshold value setters refer to.
- **Node cursor** — index of the "current" node that setters and builders operate on.
- **Selected-node cursor** — a second node index, used when wiring connections between nodes.
- **Gate cursor** — index into **allowed gates**. Only for **logic actions**.

Cursors are initialized to be at the start of their respective lists.

A cursor can be advanced to make it refer to the next item in its respective list.

When a cursor is advanced to the end of its respective list, it wraps back around to the start.

**Cursor-move actions:**
- `next_feat`:
    - description: advance the feature cursor to the next feature
    - logic action: yes
    - decision action: yes
- `next_threshold`:
    - description: advance the threshold cursor to the next threshold
    - logic action: yes
    - decision action: yes
- `next_node`:
    - description: advance the node cursor to the next node
    - logic action: yes
    - decision action: yes
- `select_node`:
    - description: copy the node cursor to the selected-node cursor
    - logic action: yes
    - decision action: yes
- `next_gate`:
    - description: advance the gate cursor to the next gate in the allowed gates list
    - logic action: yes
    - decision action: no

**Setter actions:**
- `set_feat`:
    - description: if the node cursor is at an input or branch node, wire the node's feature id to the feature cursor
    - logic action: yes
    - decision action: yes
- `set_threshold`:
    - description: if the node cursor is at an input or branch node and the node has a feature id, wire the node's threshold to the threshold cursor
    - logic action: yes
    - decision action: yes
- `set_gate`:
    - description: if the node cursor is at a gate node, wire the node's gate to the gate cursor
    - logic action: yes
    - decision action: no
- `set_in1_idx`:
    - description: if the node cursor is at a gate node, wire the node's first input to the selected-node cursor
    - logic action: yes
    - decision action: no
- `set_in2_idx`:
    - description: if the node cursor is at a gate node, wire the node's second input to the selected-node cursor
    - logic action: yes
    - decision action: no
- `set_true_idx`:
    - description: if the node cursor is at a branch or reference node, wire the node's true node index to the selected-node cursor
    - logic action: no
    - decision action: yes
- `set_false_idx`:
    - description: if the node cursor is at a branch or reference node, wire the node's false node index to the selected-node cursor
    - logic action: no
    - decision action: yes
- `set_ref_idx`:
    - description: if the node cursor is at a reference node, wire the node's reference index to the selected-node cursor
    - logic action: no
    - decision action: yes

**Builder actions:**
- `new_input`:
    - description: append an input node with no feature or threshold
    - logic action: yes
    - decision action: no
- `new_gate`:
    - description: append a gate node with no gate and no first or second input indices
    - logic action: yes
    - decision action: no
- `new_branch`:
    - description: append a branch node with no feature or threshold
    - logic action: no
    - decision action: yes
- `new_ref`:
    - description: append a reference node with no reference index
    - logic action: no
    - decision action: yes

## Meta Actions

A **meta action** is a group of primitive actions. When triggered, it runs a sequence of primitive actions. They are picked by the **optimizer** in the same way primitive actions are picked.

**Fields:**
- `label`:
    - description: name of the meta action
- `sub_actions`:
    - description: list of primitive operations to run in order

**Format**

```
<label>:
  sub_actions: ..., ..., ...
```

**Example**

```
set_feat_and_thresh:
  sub_actions: set_feat, set_threshold
advance_cursors:
  sub_actions: next_feat, next_threshold, next_node
```

## Further reading

- actions/logic_actions: Configuration specific to logic actions and networks
- actions/decision_actions: Configuration specific to decision actions and networks
"####;
