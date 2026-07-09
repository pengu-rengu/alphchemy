# Logic Actions

This page describes **logic actions**, which configure the building blocks the **optimizer** can use to construct **logic networks**.

**Fields:**
- `meta_actions`:
    - description: map of meta action labels to their respective sub actions
    - constraints: must be a valid map of meta actions
- `thresholds`:
    - description: map of feature ids to their respective min and max threshold range
    - constraints: must be a valid map of threshold ranges
- `n_thresholds`:
    - description: number of evenly-spaced threshold values for each feature
    - constraints: must be integer > 0
- `feat_order`:
    - description: list of feature ids the **feature cursor** cycles through
    - constraints: feature ids must exist and cannot be duplicated
- `allow_recurrence`:
    - description: whether gate node inputs can point to the gate itself or a later node
    - constraints: must be `true` or `false`
- `allowed_gates`:
    - description: list of gates the **gate cursor** cycles through
    - constraints: each gate must be `and`, `or`, `xor`, `nand`, `nor`, or `xnor`

**Format:**
```
type: logic
meta_actions:
  ...
thresholds: ...
  ...
n_thresholds: ...
feat_order: ..., ..., ...
allow_recurrence: ...
allowed_gates: ..., ..., ...
```

**Example:**
```
type: logic
meta_actions:
  set_feat_and_thresh:
    sub_actions: set_feat, set_threshold
  advance_cursors:
    sub_actions: next_feat, next_threshold, next_node
thresholds:
  rsi_14:
    min: 10
    max: 90
  ema_20:
    min: 0.9
    max: 1.1
n_thresholds: 5
feat_order: ema_20, rsi_14
allow_recurrence: false
allowed_gates: and, or, nand, nor
```

## Recurrence

When `allow_recurrence` is `false`, `set_in1_idx` and `set_in2_idx` only work when the **selected-node cursor** is at a node before the current **node cursor**.

## Further reading

- actions/actions: Shared threshold, feature order, cursor, primitive action, and meta action behavior
- network/logic_net: Logic node and gate behavior
