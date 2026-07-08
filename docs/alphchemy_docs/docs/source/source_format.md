# Experiment source format

This page describes the **experiment source format**, which is the text syntax used to define and queue experiments.

## Format Rules

**Rules:**
- indentation:
    - description: use two spaces per indentation level
- scalar:
    - description: use `key: value`
- nested object:
    - description: use `key:` followed by deeper-indented fields
- scalar list:
    - description: use comma-separated inline values
- strings:
    - description: do not use quotes unless a query filter value requires them
- booleans:
    - description: use `true` or `false`
- optional values:
    - description: use `null`
- object collections:
    - description: use keyed maps
- timestamps:
    - description: `start_timestamp` and `end_timestamp` accept ISO 8601 dates

The parser selects the strategy type from `strategy.base_net.type`. `base_net`, `actions`, and `penalties` must all use matching `logic` or `decision` shapes.

## Feature

```
<feature id>:
  feature: constant
  constant: float
```
OR
```
<feature id>:
  feature: raw_returns
  returns_type: log or simple
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_sma
  window: int > 0
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_ema
  window: int > 0
  smooth: int > 0
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_macd
  fast_window: int > 0
  fast_smooth: int > 0
  slow_window: int > 0
  slow_smooth: int > 0
  signal_window: int > 0
  signal_smooth: int > 0
  output: line, signal, or hist
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: rsi
  window: int > 0
  smooth: int > 0
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_bb
  window: int > 0
  std_multiplier: float > 0.0
  output: upper, lower, or width
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: stochastic
  window: int > 0
  smooth_window: int > 0
  output: percent_k or percent_d
```
OR
```
<feature id>:
  feature: normalized_atr
  window: int > 0
  smooth: int > 0
```
OR
```
<feature id>:
  feature: roc
  window: int > 0
  ohlc: open, high, low, or close
```
OR
```
<feature id>:
  feature: normalized_dc
  window: int > 0
  output: upper, lower, middle, or width
```

## Node Pointer
```
anchor: from_start or from_end
idx: int >= 0
```

## Logic Node
```
<index>:
  type: input
  threshold: float or null
  feat_id: str or null
```
OR
```
<index>:
  type: gate
  gate: and, or, xor, nand, nor, xnor, or null
  in1_idx: int or null
  in2_idx: int or null
```

## Decision Node
```
<index>:
  type: branch
  threshold: float or null
  feat_id: str or null
  true_idx: int or null
  false_idx: int or null
```
OR
```
<index>:
  type: ref
  ref_idx: int or null
  true_idx: int or null
  false_idx: int or null
```

## Network
```
type: logic
nodes:
  <collection of logic nodes>
default_value: bool
```
OR
```
type: decision
nodes:
  <collection of decision nodes>
default_value: bool
max_trail_len: int > 0
```

## Penalties
```
type: logic
node: float >= 0.0
input: float >= 0.0
gate: float >= 0.0
recurrence: float >= 0.0
feedforward: float >= 0.0
used_feat: float >= 0.0
unused_feat: float >= 0.0
```
OR
```
type: decision
node: float >= 0.0
branch: float >= 0.0
ref: float >= 0.0
leaf: float >= 0.0
non_leaf: float >= 0.0
used_feat: float >= 0.0
unused_feat: float >= 0.0
```

## Threshold
```
<feat_id>:
  min: float
  max: float
```

## Meta Action
```
<label>:
  sub_actions: action1, action2, ...
```

## Actions
```
type: logic
meta_actions:
  <collection of meta actions>
thresholds:
  <feat_id>:
    min: float
    max: float
feat_order: id1, id2, ...
n_thresholds: int > 0
allow_recurrence: bool
allowed_gates: and, or, xor
```
OR
```
type: decision
meta_actions:
  <collection of meta actions>
thresholds:
  <feat_id>:
    min: float
    max: float
feat_order: id1, id2, ...
n_thresholds: int > 0
allow_refs: bool
```

## Stop Conditions
```
max_iters: int > 0
train_patience: int >= 0
val_patience: int >= 0
```

## Optimizer
```
type: genetic
pop_size: int > 0
seq_len: int > 0
n_elites: int
mut_rate: 0.0 <= float <= 1.0
cross_rate: 0.0 <= float <= 1.0
tourn_size: int
objectives:
  <metric name>: <weight>
  ...
random_seed: int or null
```

## Backtest Schema
```
start_offset: int >= 0
start_balance: float > 0.0
delay: int >= 0
metrics: <list of: sharpe, excess_sharpe, max_drawdown, mean_hold_time, std_hold_time, total_entries, total_exits, signal_exits, stop_loss_exits, take_profit_exits, or max_hold_exits>
```

## Strategy 
```
base_net:
  <logic or decision network>
feats:
  <feature entries>
actions:
  <matching logic or decision actions>
penalties:
  <matching logic or decision penalties>
stop_conds:
  <stop conditions>
opt:
  <optimizer>
entry_ptr:
  <node pointer>
exit_ptr:
  <node pointer>
stop_loss: float > 0.0
take_profit: float > 0.0
max_hold_time: int > 0
qty: float > 0.0
```

## Experiment
```
val_size: float > 0.0
test_size: float > 0.0
cv_folds: int > 0
fold_size: 0.0 < float <= 1.0
symbol: string
start_timestamp: str
end_timestamp: str
backtest_schema:
  <backtest schema>
strategy:
  <strategy>
```

## Further reading

- source/example_a: Complete decision strategy example
- experiment/experiment: Top-level experiment fields
- features/indicators: Feature-specific parameters
