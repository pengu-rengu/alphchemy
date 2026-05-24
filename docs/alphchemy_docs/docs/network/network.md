# Network

The **network** is the shape of the strategy itself. It's a small computation that, every bar, takes feature values as input and produces true/false signals as output. Entry and Exit rules point at specific nodes in the network to read those signals.

You choose one of two network kinds when adding a child under the **Base Network** slot of your Strategy:

| Kind | Shape | Best for |
|---|---|---|
| Logic Network | A circuit of feature-vs-threshold inputs combined by boolean gates (AND, OR, XOR, …). See [network/logic_net.md](logic_net.md). | Compact rule-based strategies. Easy to interpret. Good when you want "RSI > 70 AND price below SMA". |
| Decision Network | A decision tree of feature-vs-threshold branches with true/false children. See [network/decision_net.md](decision_net.md). | Strategies whose answer depends on a chain of conditions. Good when behavior should branch by regime. |

After you choose a kind, you also pick a matching **Actions** node (Logic Actions or Decision Actions) and matching **Penalties** node (Logic Penalties or Decision Penalties) for the Strategy.

## Base network

The search doesn't start from scratch. It starts from whatever you put in the Base Network and mutates it. The base network determines:

- The initial number of nodes available to wire up.
- The Default Value emitted by any unconfigured node.

A minimal Base Network is one node plus a Default Value. You can also pre-wire nodes by filling in their fields (Feature ID, Threshold, Gate type, child indices). The search is free to overwrite those — pre-wiring just gives it a non-random starting point.

## Default Value

Every network has a **Default Value** field (true or false). It's the value returned when a node hasn't been evaluated (e.g. during warm-up bars) or when a Node Pointer falls outside the network. Almost always set this to **false** — a strategy that defaults to "exit signal on" before any indicator has warmed up will misbehave.

## Pointing Entry / Exit rules at network nodes

Every Entry and Exit rule has a **Node Pointer** child that picks one network node by index. See [experiment/strategy.md](../experiment/strategy.md).

## Complexity penalties

Penalties subtract from each candidate's score based on how big or complex the network grew during the search. They are the main brake on overfitting. The penalty fields differ per network kind:

- Logic — [network/logic_net.md](logic_net.md)
- Decision — [network/decision_net.md](decision_net.md)
