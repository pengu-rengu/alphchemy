# Example A

This page provides a complete decision-strategy experiment source example.

```
symbol: BTC_USDT
val_size: 0.2
test_size: 0.2
cv_folds: 4
fold_size: 0.7
start_timestamp: 2024-05-01T00:00:00Z
end_timestamp: 2024-11-01T00:00:00Z
backtest_schema:
  start_offset: 120
  start_balance: 10000.0
  delay: 1
  metrics: excess_sharpe, sharpe, max_drawdown, total_entries, total_exits, mean_hold_time
strategy:
  base_net:
    type: decision
    nodes:
      0:
        type: branch
        threshold: 0.0
        feat_id: macd_hist_norm
        true_idx: 1
        false_idx: 2
      1:
        type: branch
        threshold: 1.0
        feat_id: roc_12
        true_idx: null
        false_idx: 3
      2:
        type: branch
        threshold: 1.0
        feat_id: ema_34_norm
        true_idx: 3
        false_idx: null
      3:
        type: branch
        threshold: 50.0
        feat_id: rsi_14
        true_idx: 4
        false_idx: null
      4:
        type: ref
        ref_idx: 0
        true_idx: null
        false_idx: null
    max_trail_len: 6
    default_value: false
  feats:
    macd_hist_norm:
      feature: normalized_macd
      ohlc: close
      fast_window: 12
      fast_smooth: 2
      slow_window: 26
      slow_smooth: 2
      signal_window: 9
      signal_smooth: 2
      output: hist
    roc_12:
      feature: roc
      ohlc: close
      window: 12
    ema_34_norm:
      feature: normalized_ema
      window: 34
      smooth: 2
      ohlc: close
    rsi_14:
      feature: rsi
      window: 14
      smooth: 2
      ohlc: close
  actions:
    type: decision
    thresholds:
      macd_hist_norm:
        min: -0.03
        max: 0.03
      roc_12:
        min: 0.9
        max: 1.1
      ema_34_norm:
        min: 0.95
        max: 1.05
      rsi_14:
        min: 25.0
        max: 75.0
    feat_order: macd_hist_norm, roc_12, ema_34_norm, rsi_14
    n_thresholds: 9
    allow_refs: true
  penalties:
    type: decision
    node: 0.001
    branch: 0.001
    ref: 0.002
    leaf: 0.0
    non_leaf: 0.001
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
    random_seed: 123
  entry_ptr:
    anchor: from_end
    idx: 0
  exit_ptr:
    anchor: from_start
    idx: 2
  stop_loss: 0.04
  take_profit: 0.09
  max_hold_time: 72
  qty: 0.01
```

## Further reading

- source/source_format: Full source syntax reference
- experiment/experiment: Experiment field definitions
- network/decision_net: Decision network behavior
