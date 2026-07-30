pub const STRATEGY: &str = r####"# Strategy

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
- `entry`:
    - alias: `entry_schema`
    - description: long entry signal configuration
    - fields:
        - `long_ptr`: node pointer used as the long entry signal
        - `strong_long`: requires the long entry signal to be true and the long exit signal to be false
    - defaults:
        - `long_ptr.anchor`: `from_start`
        - `long_ptr.offset`: 0
        - `strong_long`: false
- `exit`:
    - alias: `exit_schema`
    - description: long exit signal configuration
    - fields:
        - `long_ptr`: node pointer used as the long exit signal
        - `strong_long`: requires the long exit signal to be true and the long entry signal to be false
    - defaults:
        - `long_ptr.anchor`: `from_start`
        - `long_ptr.offset`: 0
        - `strong_long`: false
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
  entry:
    long_ptr:
      ...
    strong_long: ...
  exit:
    long_ptr:
      ...
    strong_long: ...
  stop_loss: ...
  take_profit: ...
  max_hold_time: ...
  qty: ...
```

## Node Pointer

`entry.long_ptr` and `exit.long_ptr` read long signals from the network.

In logic networks, node pointers read from the node list. In decision networks, node pointers read from the trail of visited nodes.

## Further reading

- network/network: Node pointer fields and behavior
- experiment/backtest: Trade simulation and exit ordering
- optimizer/optimizer: Stop conditions and search behavior
"####;
