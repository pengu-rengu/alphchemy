pub const LOGIC_NET: &str = r####"# Logic Network

This page describes **logic networks**, which evaluate a list of nodes into true or false signals.

Every bar, nodes are evaluated in order from first to last. Input nodes compare feature values against thresholds. Gate nodes combine other nodes' values with logic gates.

## Fields

**Fields:**
- `type`:
    - description: network type
    - constraints: must be `logic`
- `nodes`:
    - description: indexed map of input and gate nodes
    - constraints: indexes must be contiguous and start from 0
- `default_value`:
    - description: fallback value for nodes with missing gates, inputs, or thresholds, or out-of-range node pointers
    - constraints: must be `true` or `false`

**Format:**
```
type: logic
nodes:
  <collection of logic nodes>
default_value: ...
```

**Example:**
```
type: logic
nodes:
  0:
    type: input
    threshold: 50
    feat_id: rsi_14
  1:
    type: input
    threshold: 1.0
    feat_id: ema_20
  2:
    type: gate
    gate: and
    in1_idx: 0
    in2_idx: 1
default_value: false
```

## Input Node

An **input node** compares one feature value against a threshold. It is true when `feature[i] > threshold`.

**Fields:**
- `type`:
    - description: node type
    - constraints: must be `input`
- `threshold`:
    - description: cutoff value
    - constraints: must be a number or `null`
- `feat_id`:
    - description: feature id to compare
    - constraints: must be a strategy feature id or `null`

**Format:**
```
<index>:
  type: input
  threshold: ...
  feat_id: ...
```

**Example:**
```
0:
  type: input
  threshold: 50
  feat_id: rsi_14
```

If `threshold` or `feat_id` is `null`, the node returns `default_value`.

## Gate Node

A **gate node** combines two node values.

**Fields:**
- `type`:
    - description: node type
    - constraints: must be `gate`
- `gate`:
    - description: boolean gate to apply
    - constraints: must be `and`, `or`, `xor`, `nand`, `nor`, `xnor`, or `null`
- `in1_idx`:
    - description: first input node index
    - constraints: must point to an existing node or be `null`
- `in2_idx`:
    - description: second input node index
    - constraints: must point to an existing node or be `null`

**Format:**
```
<index>:
  type: gate
  gate: ...
  in1_idx: ...
  in2_idx: ...
```

**Example:**
```
2:
  type: gate
  gate: and
  in1_idx: 0
  in2_idx: 1
```

If `gate` is `null`, the node returns `default_value`. If `in1_idx` or `in2_idx` is `null`, that input uses `default_value`.

## Gates

**Gates:**
- `and`:
    - description: true when both inputs are true
- `or`:
    - description: true when either input is true
- `xor`:
    - description: true when exactly one input is true
- `nand`:
    - description: true when not both inputs are true
- `nor`:
    - description: true when neither input is true
- `xnor`:
    - description: true when both inputs have the same value

## Recurrence

A gate node input is **feedforward** if it points to an earlier node, reading that node's current-bar value.

A gate node input is **recurrent** if it points to itself or a later node, reading that node's previous stored value from the last bar.

Recurrent connections allow the network to maintain state across bars.

## Penalties

All penalty values must be >= 0.

**Fields:**
- `node`:
    - description: penalty for each node
    - constraints: must be >= 0
- `input`:
    - description: extra penalty for each input node
    - constraints: must be >= 0
- `gate`:
    - description: extra penalty for each gate node
    - constraints: must be >= 0
- `recurrence`:
    - description: penalty for a gate input pointing to itself or a later node
    - constraints: must be >= 0
- `feedforward`:
    - description: penalty for a gate input pointing to an earlier node
    - constraints: must be >= 0
- `used_feat`:
    - description: penalty for each distinct feature used by input nodes
    - constraints: must be >= 0
- `unused_feat`:
    - description: penalty for each strategy feature not used by input nodes
    - constraints: must be >= 0

**Format:**
```
type: logic
node: ...
input: ...
gate: ...
recurrence: ...
feedforward: ...
used_feat: ...
unused_feat: ...
```

**Example:**
```
type: logic
node: 0.001
input: 0.001
gate: 0.002
recurrence: 0.003
feedforward: 0.001
used_feat: 0.001
unused_feat: 0.0
```

## Further reading

- network/network: Shared network and node pointer behavior
- actions/logic_actions: Actions that construct logic networks
- experiment/overfitting: How penalties affect overfitting
"####;
