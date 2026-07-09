# Example

This page provides a complete experiment source example from experiment 301.

```text
symbol: BTC_USDT
val_size: 0.2
test_size: 0.2
cv_folds: 5
fold_size: 0.9
start_timestamp: 2024-06-01T00:00:00Z
end_timestamp: 2026-06-01T00:00:00Z
backtest_schema:
  start_offset: 120
  start_balance: 10000.0
  delay: 1
  metrics: excess_sharpe, sharpe, max_drawdown, total_entries, take_profit_exits, stop_loss_exits, max_hold_exits, mean_hold_time
strategy:
  base_net:
    type: logic
    nodes:
      0:
        type: input
        threshold: 1.02
        feat_id: dc_upper
      1:
        type: input
        threshold: 0.006
        feat_id: atr_14
      2:
        type: gate
        gate: nand
        in1_idx: 0
        in2_idx: 0
      3:
        type: gate
        gate: nand
        in1_idx: 1
        in2_idx: 1
      4:
        type: gate
        gate: and
        in1_idx: 2
        in2_idx: 3
      5:
        type: input
        threshold: 1.0
        feat_id: zero
    default_value: false
  feats:
    dc_upper:
      feature: normalized_dc
      window: 10
      output: upper
    atr_14:
      feature: normalized_atr
      window: 14
      smooth: 2
    zero:
      feature: constant
      constant: 0.0
  actions:
    type: logic
    thresholds:
      dc_upper:
        min: 1.0
        max: 1.05
      atr_14:
        min: 0.001
        max: 0.015
      zero:
        min: 1.0
        max: 2.0
    feat_order: dc_upper, atr_14, zero
    n_thresholds: 9
    allow_recurrence: false
  penalties:
    type: logic
    node: 0.001
    input: 0.001
    gate: 0.001
    recurrence: 0.002
    feedforward: 0.0
    used_feat: 0.001
    unused_feat: 0.0
  stop_conds:
    max_iters: 30
    train_patience: 8
    val_patience: 8
  opt:
    objectives:
      excess_sharpe: 1.0
    type: genetic
    pop_size: 40
    seq_len: 12
    n_elites: 4
    mut_rate: 0.15
    cross_rate: 0.7
    tourn_size: 4
    random_seed: 2190
  entry_ptr:
    anchor: from_start
    idx: 4
  exit_ptr:
    anchor: from_start
    idx: 5
  stop_loss: 0.02
  take_profit: 0.07
  max_hold_time: 168
  qty: 0.01
```

## Further reading

- source/source_format: Full source syntax reference
- experiment/experiment: Experiment field definitions
- network/logic_net: Logic network behavior
