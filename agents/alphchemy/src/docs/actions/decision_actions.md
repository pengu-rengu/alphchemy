# Decision Actions

This page describes **decision actions**, which configure the building blocks the **optimizer** can use to construct **decision networks**.

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
- `allow_refs`:
    - description: whether `new_ref` can append reference nodes
    - constraints: must be `true` or `false`

**Format:**
```
type: decision
meta_actions:
  ...
thresholds:
  ...
feat_order: ..., ..., ...
n_thresholds: ...
allow_refs: ...
```

**Example:**
```
type: decision
meta_actions:
  set_feat_and_thresh:
    sub_actions: set_feat, set_threshold
  wire_branch:
    sub_actions: select_node, set_true_idx, next_node
thresholds:
  rsi_14:
    min: 10
    max: 90
  ema_20:
    min: 0.9
    max: 1.1
feat_order: ema_20, rsi_14
n_thresholds: 5
allow_refs: true
```

## References

When `allow_refs` is `false`, `new_ref` does nothing. When `allow_refs` is `true`, `new_ref` can append a reference node.

## Further reading

- actions/actions: Shared threshold, feature order, cursor, primitive action, and meta action behavior
- network/decision_net: Decision node and reference behavior
