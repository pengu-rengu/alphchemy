use alphchemy::experiment::experiment::ExperimentVariant;
use alphchemy::experiment::backtest::BacktestMetric;
use alphchemy::network::network::Anchor;
use alphchemy::network::logic_net::LogicNode;
use alphchemy::parse::parse_experiment::parse_experiment;

const LOGIC_SOURCE: &str = "val_size: 0.2
test_size: 0.2
cv_folds: 3
fold_size: 0.7
symbol: ETH_USDT
start_timestamp: Jan 1 2024 00:00
end_timestamp: Jul 1 2024 00:00
backtest_schema:
  start_offset: 80
  start_balance: 10000
  delay: 1
  metrics: excess_sharpe, sharpe, total_entries, total_exits, mean_hold_time
strategy:
  base_net:
    type: logic
    nodes:
      0:
        type: input
        threshold: 0.0
        feat_id: close_log_ret
      1:
        type: input
        threshold: 1.0
        feat_id: ema_21_norm
      2:
        type: gate
        gate: and
        in1_idx: 0
        in2_idx: 1
      3:
        type: input
        threshold: 70.0
        feat_id: rsi_14
    default_value: false
  feats:
    close_log_ret:
      feature: raw_returns
      returns_type: log
      ohlc: close
    sma_50_norm:
      feature: normalized_sma
      window: 50
      ohlc: close
    ema_21_norm:
      feature: normalized_ema
      window: 21
      smooth: 2
      ohlc: close
    rsi_14:
      feature: rsi
      window: 14
      smooth: 2
      ohlc: close
  actions:
    type: logic
    thresholds:
      close_log_ret:
        min: -0.03
        max: 0.03
      sma_50_norm:
        min: 0.95
        max: 1.05
      ema_21_norm:
        min: 0.95
        max: 1.05
      rsi_14:
        min: 25.0
        max: 75.0
    feat_order: close_log_ret, sma_50_norm, ema_21_norm, rsi_14
    n_thresholds: 9
    allow_recurrence: false
    allowed_gates: and, or, xor
  penalties:
    type: logic
    node: 0.001
    input: 0.001
    gate: 0.001
    recurrence: 0.01
    feedforward: 0.0
    used_feat: 0.001
    unused_feat: 0.0
  stop_conds:
    max_iters: 6
    train_patience: 3
    val_patience: 3
  opt:
    type: genetic
    pop_size: 12
    seq_len: 8
    n_elites: 2
    mut_rate: 0.1
    cross_rate: 0.7
    tourn_size: 3
    objectives:
      excess_sharpe: 1.0
    random_seed: 7
  entry_ptr:
    anchor: from_start
    idx: 2
  exit_ptr:
    anchor: from_start
    idx: 3
  stop_loss: 0.04
  take_profit: 0.08
  max_hold_time: 72
  qty: 0.01
";

#[test]
fn parses_logic_example() {
    let variant = parse_experiment(LOGIC_SOURCE).expect("logic source should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.cv_folds, 3);
    assert_eq!(experiment.symbol, "ETH_USDT");
    assert_eq!(experiment.start_timestamp, "2024-01-01T00:00:00");
    assert_eq!(experiment.end_timestamp, "2024-07-01T00:00:00");

    let schema = &experiment.backtest_schema;
    assert_eq!(schema.start_offset, 80);
    assert_eq!(schema.start_balance, 10000.0);
    assert_eq!(schema.metrics.len(), 5);

    let strategy = &experiment.strategy;
    assert_eq!(strategy.opt.objectives.len(), 1);
    assert_eq!(strategy.opt.objectives[0].metric, BacktestMetric::ExcessSharpe);
    assert_eq!(strategy.opt.objectives[0].weight, 1.0);
    assert_eq!(strategy.opt.random_seed, Some(7));
    assert_eq!(strategy.feats.len(), 4);
    assert_eq!(strategy.base_net.nodes.len(), 4);
    assert_eq!(strategy.actions.n_thresholds, 9);
    assert_eq!(strategy.actions.allowed_gates.len(), 3);
    assert_eq!(strategy.actions.thresholds.len(), 4);
    assert_eq!(strategy.qty, 0.01);
    assert_eq!(strategy.max_hold_time, 72);
    assert_eq!(strategy.entry_ptr.idx, 2);
    assert!(matches!(strategy.entry_ptr.anchor, Anchor::FromStart));
}

const DECISION_SOURCE: &str = "cv_folds: 4
backtest:
  start_balance: 5000
  metrics: excess_sharpe
strategy:
  base_net:
    type: decision
    max_trail_len: 6
    nodes:
      0:
        type: branch
        threshold: 0.0
        feat_id: roc_12
        true_idx: 1
        false_idx: null
      1:
        type: ref
        ref_idx: 0
    default_value: false
  feats:
    roc_12:
      feature: roc
      window: 12
  actions:
    type: decision
    thresholds:
      roc_12:
        min: 0.9
        max: 1.1
    feat_order: roc_12
    n_thresholds: 9
    allow_refs: true
";

#[test]
fn parses_decision_with_aliases_and_defaults() {
    let variant = parse_experiment(DECISION_SOURCE).expect("decision source should parse");

    let ExperimentVariant::Decision(experiment) = variant else {
        panic!("expected decision experiment");
    };

    assert_eq!(experiment.cv_folds, 4);
    assert_eq!(experiment.val_size, 0.2);
    assert_eq!(experiment.backtest_schema.start_balance, 5000.0);
    assert_eq!(experiment.backtest_schema.metrics.len(), 1);

    let strategy = &experiment.strategy;
    assert_eq!(strategy.base_net.max_trail_len, 6);
    assert_eq!(strategy.base_net.nodes.len(), 2);
    assert!(strategy.actions.allow_refs);
    assert_eq!(strategy.feats.len(), 1);
}

#[test]
fn empty_source_uses_defaults() {
    let variant = parse_experiment("strategy:\n  base_net:\n    type: logic").expect("defaults should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.cv_folds, 5);
    assert_eq!(experiment.symbol, "BTC_USDT");
    assert_eq!(experiment.val_size, 0.2);
    assert_eq!(experiment.test_size, 0.2);
    assert_eq!(experiment.backtest_schema.metrics.len(), 1);
    assert_eq!(experiment.strategy.qty, 0.01);
}

// Nodes 1 and 0 are written out of order; each must land at the index given by
// its key, not by source order.
const OUT_OF_ORDER_NODES_SOURCE: &str = "cv_folds: 2
backtest:
  metrics: excess_sharpe
strategy:
  base_net:
    type: logic
    nodes:
      1:
        type: gate
        gate: and
        in1_idx: 0
        in2_idx: 0
      0:
        type: input
        threshold: 0.5
        feat_id: feat_a
    default_value: false
  feats:
    feat_a:
      feature: rsi
      window: 14
  actions:
    type: logic
    thresholds:
      feat_a:
        min: 0.0
        max: 1.0
    feat_order: feat_a
    n_thresholds: 9
";

#[test]
fn places_nodes_by_index_key_not_source_order() {
    let variant = parse_experiment(OUT_OF_ORDER_NODES_SOURCE).expect("out-of-order nodes should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    let nodes = &experiment.strategy.base_net.nodes;
    assert_eq!(nodes.len(), 2);

    let LogicNode::Input(input) = &nodes[0] else {
        panic!("node 0 should be the input placed by key");
    };
    assert_eq!(input.feat_id.as_deref(), Some("feat_a"));
    assert_eq!(input.threshold, Some(0.5));
    assert!(matches!(nodes[1], LogicNode::Gate(_)), "node 1 should be the gate placed by key");
}

#[test]
fn allows_feat_order_subset() {
    let source = "strategy:
  base_net:
    type: logic
  feats:
    feat_a:
      feature: rsi
      window: 14
    feat_b:
      feature: roc
      window: 12
  actions:
    type: logic
    thresholds:
      feat_a:
        min: 0.0
        max: 1.0
      feat_b:
        min: 0.0
        max: 1.0
    feat_order: feat_a
";
    let variant = parse_experiment(source).expect("feat_order subset should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.strategy.actions.feat_order.len(), 1);
    assert_eq!(experiment.strategy.actions.feat_order[0], "feat_a");
}

#[test]
fn rejects_unknown_feat_order_feature_id() {
    let source = "strategy:
  base_net:
    type: logic
  feats:
    feat_a:
      feature: rsi
      window: 14
  actions:
    type: logic
    thresholds:
      feat_a:
        min: 0.0
        max: 1.0
    feat_order: missing
";
    let result = parse_experiment(source);
    let Err(error) = result else {
        panic!("unknown feat_order feature id should fail");
    };

    assert!(error.contains("feature with id \"missing\" not found"));
}

#[test]
fn rejects_duplicate_node_index() {
    let source = "strategy:\n  base_net:\n    type: logic\n    nodes:\n      0:\n        type: input\n      0:\n        type: gate";
    assert!(parse_experiment(source).is_err());
}

#[test]
fn rejects_out_of_range_node_index() {
    let source = "strategy:\n  base_net:\n    type: logic\n    nodes:\n      5:\n        type: input";
    assert!(parse_experiment(source).is_err());
}

#[test]
fn rejects_duplicate_threshold_feature_id() {
    let source = "strategy:\n  base_net:\n    type: logic\n  actions:\n    thresholds:\n      feat_a:\n        min: 0.0\n        max: 1.0\n      feat_a:\n        min: 0.0\n        max: 1.0";
    let result = parse_experiment(source);
    let Err(error) = result else {
        panic!("duplicate threshold should fail");
    };
    assert!(error.contains("duplicate threshold"));
}

#[test]
fn rejects_dash_prefixed_scalar_lists() {
    let source = "backtest:\n  metrics:\n    - excess_sharpe";
    let result = parse_experiment(source);
    let Err(error) = result else {
        panic!("dash-prefixed list should fail");
    };
    assert!(error.contains("metrics must be an inline comma-separated list"));
}

#[test]
fn rejects_empty_bracket_scalar_lists() {
    let source = "backtest:\n  metrics: []";
    let result = parse_experiment(source);
    let Err(error) = result else {
        panic!("empty bracket list should fail");
    };
    assert!(error.contains("metrics must omit the key instead of using []"));
}

#[test]
fn rejects_empty_bracket_meta_actions() {
    let source = "strategy:\n  actions:\n    meta_actions: []";
    let result = parse_experiment(source);
    let Err(error) = result else {
        panic!("empty bracket meta_actions should fail");
    };
    assert!(error.contains("meta_actions must omit the key instead of using []"));
}
