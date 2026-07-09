# Strategy

This page describes **strategies**, which configure the features, network, optimizer, actions, penalties, entry/exit signals, and risk settings used in an experiment.

At most one position is open at any time.

## Fields

**Fields:**
- `base_net`:
    - description: starting network the optimizer mutates
    - constraints: must be a valid logic or decision network
- `feats`:
    - description: feature map available to the network
    - constraints: feature ids must be unique
- `actions`:
    - description: actions the optimizer can apply
    - constraints: action type must match `base_net.type`
- `penalties`:
    - description: complexity penalties subtracted from candidate scores
    - constraints: penalty type must match `base_net.type`
- `stop_conds`:
    - description: conditions that stop optimization
    - constraints: must be valid stop conditions
- `opt`:
    - description: optimizer configuration
    - constraints: must be a valid optimizer
- `entry_ptr`:
    - description: node pointer used as the entry signal
    - constraints: must be a valid node pointer
- `exit_ptr`:
    - description: node pointer used as the exit signal
    - constraints: must be a valid node pointer
- `stop_loss`:
    - description: fractional loss threshold from entry price
    - constraints: must be > 0.0
- `take_profit`:
    - description: fractional profit threshold from entry price
    - constraints: must be > 0.0
- `max_hold_time`:
    - description: maximum number of bars to hold a position
    - constraints: must be integer > 0
- `qty`:
    - description: position size opened on entry
    - constraints: must be > 0.0

**Format:**
```
strategy:
  base_net:
    ...
  feats:
    ...
  actions:
    ...
  penalties:
    ...
  stop_conds:
    ...
  opt:
    ...
  entry_ptr:
    ...
  exit_ptr:
    ...
  stop_loss: ...
  take_profit: ...
  max_hold_time: ...
  qty: ...
```

## Node Pointer

`entry_ptr` and `exit_ptr` read signals from the network.

In logic networks, node pointers read from the node list. In decision networks, node pointers read from the trail of visited nodes.

## Further reading

- network/network: Node pointer fields and behavior
- experiment/backtest: Trade simulation and exit ordering
- optimizer/optimizer: Stop conditions and search behavior
