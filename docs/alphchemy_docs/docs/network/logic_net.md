# Logic Network

A Logic Network is a list of nodes that produce true/false values. There are two kinds of node you can add under it: **Input Node** and **Gate Node**.

- An Input Node compares one feature against a threshold. Outputs `true` when `feature[i] > threshold`.
- A Gate Node takes two other nodes as inputs and combines them with a boolean gate.

Every bar, all nodes are evaluated in order; Entry / Exit rules read signals from the node(s) their Node Pointers point at.

## Logic Network fields

| Field | Meaning |
|---|---|
| Default Value | Boolean returned when a node hasn't been evaluated yet or a Node Pointer falls outside the network. Almost always `false`. |

Children: one **Nodes** slot containing any mix of Input Nodes and Gate Nodes.

## Input Node fields

| Field | Meaning |
|---|---|
| Feature ID | ID of one of the features listed under your Strategy's Features slot. Optional — if blank, the search will fill it in. |
| Threshold | The cutoff. The node is true when the feature's value is strictly greater than this. Optional. |

## Gate Node fields

| Field | Meaning |
|---|---|
| Gate | One of `and`, `or`, `xor`, `nand`, `nor`, `xnor`. Optional. |
| in1Idx | Index of the node feeding this gate's first input. Must be < the number of nodes. Optional. |
| in2Idx | Same, for the second input. |

If in1Idx or in2Idx is blank, that input uses the network's Default Value.

## Gate semantics

| Gate | True when |
|---|---|
| and | both inputs are true |
| or | either input is true |
| xor | exactly one input is true |
| nand | not both true |
| nor | neither true |
| xnor | inputs agree |

## Logic Penalties

The Penalties node attached to your Strategy controls how the search is penalized for building a complex network. All values must be ≥ 0.

| Field | What it counts |
|---|---|
| Node Penalty | Charged once per node in the network. The basic complexity tax. |
| Input Node Penalty | Extra charge per Input Node. Discourages adding more feature comparisons. |
| Gate Node Penalty | Extra charge per Gate Node. Discourages adding more gates. |
| Recurrent Node Penalty | Extra charge per gate input that points to a node with index ≥ the gate's own index (a feedback / cycle wire). |
| Feedforward Node Penalty | Extra charge per gate input that points to a node with index < the gate's index (a normal forward wire). Set this to 0 if you want forward connections free. |
| Used Feature Penalty | Charged once per *distinct* feature actually referenced by any Input Node. |
| Unused Feature Penalty | Charged once per feature in the Features slot that no Input Node references. Encourages using all the features you provide; pair with a small Used Feature Penalty to balance. |

### Sensible starting values

| Field | Starting value |
|---|---|
| Node Penalty | 0.005 |
| Input Node Penalty | 0.001 |
| Gate Node Penalty | 0.001 |
| Recurrent Node Penalty | 0 |
| Feedforward Node Penalty | 0 |
| Used Feature Penalty | 0 |
| Unused Feature Penalty | 0 |

If you see overfitting (see [../experiment/overfitting.md](../experiment/overfitting.md)), raise Node Penalty, Input Node Penalty, and Gate Node Penalty together. If the search can't find anything interesting, lower them.

Recurrent Node Penalty > 0 discourages feedback wiring, which is the harder-to-reason-about case. If you want a purely forward circuit, set it high (e.g. 0.1) and turn off Allow Recurrence on the Logic Actions node.

## How big should the network be?

The Base Network sets the starting node count, but the search can also grow it. Bigger networks fit better in training but overfit faster. Start small — 3 to 8 nodes — and only grow if test results are clearly improving.
