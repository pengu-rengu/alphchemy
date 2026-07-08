# Decision Network

This page describes **decision networks**, which walk a trail through branch and reference nodes.

Every bar starts at node 0. Each node produces a true or false value, then the trail follows `true_idx` or `false_idx`. Entry and exit rules read signals from positions in the trail.

## Fields

**Fields:**
- `type`:
    - description: network type
    - constraints: must be `decision`
- `nodes`:
    - description: indexed map of branch and reference nodes
    - constraints: indexes must be contiguous and start from 0
- `default_value`:
    - description: fallback value for unconfigured nodes, unconfigured references, or out-of-range node pointers
    - constraints: must be `true` or `false`
- `max_trail_len`:
    - description: maximum number of nodes the trail can visit on one bar
    - constraints: must be integer > 0

**Format:**
```
type: decision
nodes:
  <collection of decision nodes>
default_value: ...
max_trail_len: ...
```

**Example:**
```
type: decision
nodes:
  0:
    type: branch
    threshold: 50
    feat_id: rsi_14
    true_idx: 1
    false_idx: 2
  1:
    type: branch
    threshold: 1.0
    feat_id: ema_20
    true_idx: null
    false_idx: null
  2:
    type: ref
    ref_idx: 0
    true_idx: null
    false_idx: null
default_value: false
max_trail_len: 6
```

## Branch Node

A **branch node** compares one feature value against a threshold. It is true when `feature[i] > threshold`.

**Fields:**
- `type`:
    - description: node type
    - constraints: must be `branch`
- `threshold`:
    - description: cutoff value
    - constraints: must be a number or `null`
- `feat_id`:
    - description: feature id to compare
    - constraints: must be a strategy feature id or `null`
- `true_idx`:
    - description: next node index when the node is true
    - constraints: must point to an existing node or be `null`
- `false_idx`:
    - description: next node index when the node is false
    - constraints: must point to an existing node or be `null`

**Format:**
```
<index>:
  type: branch
  threshold: ...
  feat_id: ...
  true_idx: ...
  false_idx: ...
```

**Example:**
```
0:
  type: branch
  threshold: 50
  feat_id: rsi_14
  true_idx: 1
  false_idx: 2
```

If `threshold` or `feat_id` is `null`, the node returns `default_value`. If `true_idx` or `false_idx` is `null`, the trail stops on that side.

## Reference Node

A **reference node** reuses another node's current value.

**Fields:**
- `type`:
    - description: node type
    - constraints: must be `ref`
- `ref_idx`:
    - description: node index to read
    - constraints: must point to an existing node or be `null`
- `true_idx`:
    - description: next node index when the node is true
    - constraints: must point to an existing node or be `null`
- `false_idx`:
    - description: next node index when the node is false
    - constraints: must point to an existing node or be `null`

**Format:**
```
<index>:
  type: ref
  ref_idx: ...
  true_idx: ...
  false_idx: ...
```

**Example:**
```
2:
  type: ref
  ref_idx: 0
  true_idx: null
  false_idx: null
```

If `ref_idx` is `null`, the node returns `default_value`.

## Penalties

**Fields:**
- `node`:
    - description: penalty for each node
    - constraints: must be >= 0
- `branch`:
    - description: extra penalty for each branch node
    - constraints: must be >= 0
- `ref`:
    - description: extra penalty for each reference node
    - constraints: must be >= 0
- `leaf`:
    - description: penalty for each missing `true_idx` or `false_idx`
    - constraints: must be >= 0
- `non_leaf`:
    - description: penalty for each present `true_idx` or `false_idx`
    - constraints: must be >= 0
- `used_feat`:
    - description: penalty for each distinct feature used by branch nodes
    - constraints: must be >= 0
- `unused_feat`:
    - description: penalty for each strategy feature not used by branch nodes
    - constraints: must be >= 0

**Format:**
```
type: decision
node: ...
branch: ...
ref: ...
leaf: ...
non_leaf: ...
used_feat: ...
unused_feat: ...
```

**Example:**
```
type: decision
node: 0.001
branch: 0.001
ref: 0.002
leaf: 0.0
non_leaf: 0.001
used_feat: 0.001
unused_feat: 0.0
```

## Further reading

- network/network: Shared network and node pointer behavior
- actions/decision_actions: Actions that construct decision networks
- experiment/overfitting: How penalties affect overfitting
