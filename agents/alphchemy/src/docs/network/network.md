# Network

This page describes **networks**, which are the core logic of a **strategy**. On every bar, a network uses feature values to produce true or false signals for every node. Entry and exit rules read those signals through **node pointers**.

## Base network

The **optimizer** starts from the **base network** and mutates it using **actions**. The base network determines the initial nodes, initial wiring, and fallback value.

## Node Pointer

A **node pointer** selects a signal from a network.

In a logic network, it points into the list of nodes.

In a decision network, it points into the trail of visited nodes.

A node pointer has an anchor and an offset. The anchor can either be at the start or at the end, and the offset determines how far to move from that anchor.

If the pointer is out of range, the pointer's value is the network's `default_value`.

**Fields:**
- `anchor`:
    - description: whether the offset is from the start or end of the list
    - constraints: must be either `from_start` or `from_end`
- `idx`:
    - description: offset from the anchor
    - constraints: must be integer >= 0

**Format:**
```
anchor: ...
idx: ...
```

**Example:**
```
anchor: from_end
idx: 0
```

## Further reading

- network/logic_net: Logic network fields, nodes, gates, and penalties
- network/decision_net: Decision network fields, nodes, references, and penalties
- experiment/strategy: Entry and exit pointers
