# Network

The **network** is the logic of the **strategy**. It's computation that, every bar, takes feature values as input and produces true or false signals as output. The **strategy**'s entry and exit rules point at specific nodes in the network and read their signals.

There are two kinds of networks:
- 

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
