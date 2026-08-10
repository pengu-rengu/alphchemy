use alphchemy_engine::actions::actions::Action;
use alphchemy_engine::experiment::experiment::{ExperimentVariant, TimeInterval};
use alphchemy_engine::experiment::backtest::BacktestMetric;
use alphchemy_engine::network::network::Anchor;
use alphchemy_engine::network::logic_net::LogicNode;
use alphchemy_engine::optimizer::genetic::GeneticOpt;
use alphchemy_parse::parse::parse::{Fields, to_lines};
use alphchemy_parse::parse::parse_experiment::parse_experiment::parse_experiment;
use alphchemy_parse::parse::parse_optimizer::parse_genetic::parse_opt;

const LOGIC_SOURCE: &str = "val_size: 0.2
test_size: 0.2
cv_folds: 3
fold_size: 0.7
symbol: ETH_USDT
time_interval: 1h
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
    meta_actions:
      set_input:
        sub_actions: select_node, set_in1_idx, set_in2_idx
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
    action_weights:
      next_threshold: 1.5
      set_input: 2.3
    random_seed: 7
  entry:
    long_ptr:
      anchor: from_start
      offset: 2
    strong_long: true
  exit:
    long_ptr:
      anchor: from_start
      offset: 3
    strong_long: true
    stop_loss: 0.04
    take_profit: 0.08
    max_hold_time: 72
  qty: 0.01
";

const MINIMAL_SOURCE: &str = "start_timestamp: 2024-01-01
end_timestamp: 2024-07-01
strategy:
  feats:
    rsi_14:
      feature: rsi
    ema_20:
      feature: normalized_ema
      window: 20
";

fn parse_opt_source(source: &str, actions_list: &[Action]) -> Result<GeneticOpt, String> {
    let lines = to_lines(source);
    let fields = Fields::from_lines(&lines)?;
    parse_opt(Some(fields), actions_list)
}

#[test]
fn parses_logic_example() {
    let variant = parse_experiment(LOGIC_SOURCE).expect("logic source should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.cv_folds, 3);
    assert_eq!(experiment.symbol, "ETH_USDT");
    assert_eq!(experiment.time_interval, TimeInterval::OneHour);
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
    assert_eq!(strategy.opt.action_weights[&Action::NextThreshold], 1.5);
    assert_eq!(strategy.opt.action_weights[&Action::MetaAction("set_input".to_string())], 2.3);
    assert_eq!(strategy.opt.random_seed, Some(7));
    assert_eq!(strategy.feats.len(), 4);
    assert_eq!(strategy.base_net.nodes.len(), 4);
    assert_eq!(strategy.actions.n_thresholds, 9);
    assert_eq!(strategy.actions.allowed_gates.len(), 3);
    assert_eq!(strategy.actions.thresholds.len(), 4);
    assert_eq!(strategy.qty, 0.01);
    assert_eq!(strategy.exit_schema.stop_loss, 0.04);
    assert_eq!(strategy.exit_schema.take_profit, 0.08);
    assert_eq!(strategy.exit_schema.max_hold_time, 72);
    assert_eq!(strategy.entry_schema.entry_long_ptr.offset, 2);
    assert!(strategy.entry_schema.strong_entry_long);
    assert!(strategy.exit_schema.strong_exit_long);
    assert!(matches!(strategy.entry_schema.entry_long_ptr.anchor, Anchor::FromStart));
}

#[test]
fn parses_entry_and_exit_schema_aliases() {
    let source = "strategy:
  entry_schema:
    long_ptr:
      anchor: from_start
      offset: 2
    strong_long: true
  exit_schema:
    long_ptr:
      anchor: from_end
      offset: 3
    strong_long: true
    stop_loss: 0.05
    take_profit: 0.09
    max_hold_time: 48
";
    let variant = parse_experiment(source).expect("strategy schema aliases should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.strategy.entry_schema.entry_long_ptr.offset, 2);
    assert!(experiment.strategy.entry_schema.strong_entry_long);
    assert_eq!(experiment.strategy.exit_schema.exit_long_ptr.offset, 3);
    assert!(experiment.strategy.exit_schema.strong_exit_long);
    assert_eq!(experiment.strategy.exit_schema.stop_loss, 0.05);
    assert_eq!(experiment.strategy.exit_schema.take_profit, 0.09);
    assert_eq!(experiment.strategy.exit_schema.max_hold_time, 48);
}

#[test]
fn canonical_entry_and_exit_fields_take_precedence() {
    let source = "strategy:
  entry_schema:
    long_ptr:
      offset: 4
  entry:
    long_ptr:
      offset: 2
  exit_schema:
    long_ptr:
      offset: 5
    stop_loss: 0.05
    take_profit: 0.09
    max_hold_time: 48
  exit:
    long_ptr:
      offset: 3
    stop_loss: 0.04
    take_profit: 0.08
    max_hold_time: 72
";
    let variant = parse_experiment(source).expect("canonical strategy fields should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.strategy.entry_schema.entry_long_ptr.offset, 2);
    assert_eq!(experiment.strategy.exit_schema.exit_long_ptr.offset, 3);
    assert_eq!(experiment.strategy.exit_schema.stop_loss, 0.04);
    assert_eq!(experiment.strategy.exit_schema.take_profit, 0.08);
    assert_eq!(experiment.strategy.exit_schema.max_hold_time, 72);
}

#[test]
fn rejects_flat_strategy_signal_fields() {
    let source = "strategy:
  entry_ptr:
    offset: 2
";
    let error = match parse_experiment(source) {
        Ok(_) => panic!("flat signal field should fail"),
        Err(error) => error
    };

    assert_eq!(error, "entry_ptr was replaced by entry.long_ptr");
}

#[test]
fn parses_minimal_source_from_defaults() {
    let result = parse_experiment(MINIMAL_SOURCE);
    let variant = result.expect("minimal source should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("minimal source should default to a logic experiment");
    };

    assert_eq!(experiment.start_timestamp, "2024-01-01T00:00:00");
    assert_eq!(experiment.end_timestamp, "2024-07-01T00:00:00");
    assert_eq!(experiment.cv_folds, 5);
    assert_eq!(experiment.symbol, "BTC_USDT");
    assert_eq!(experiment.backtest_schema.metrics.len(), 1);

    let strategy = &experiment.strategy;
    assert_eq!(strategy.feats.len(), 2);
    assert!(strategy.base_net.nodes.is_empty());
    assert_eq!(strategy.actions.feat_order, vec!["rsi_14".to_string(), "ema_20".to_string()]);
    assert_eq!(strategy.actions.thresholds.len(), 2);
    assert_eq!(strategy.actions.thresholds["rsi_14"].min, 0.0);
    assert_eq!(strategy.actions.thresholds["rsi_14"].max, 100.0);
    assert_eq!(strategy.actions.thresholds["ema_20"].min, 0.9);
    assert_eq!(strategy.actions.thresholds["ema_20"].max, 1.1);
    assert_eq!(strategy.actions.n_thresholds, 5);
    assert_eq!(strategy.opt.pop_size, 100);
    assert_eq!(strategy.stop_conds.max_iters, 100);
    assert_eq!(strategy.qty, 0.01);
}

#[test]
fn parses_timestamps_without_seconds() {
    let source = MINIMAL_SOURCE.replace("2024-01-01", "2024-01-01T01:02");
    let source = source.replace("2024-07-01", "2024-07-01T03:04");
    let variant = parse_experiment(&source).expect("minute-precision timestamps should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.start_timestamp, "2024-01-01T01:02:00");
    assert_eq!(experiment.end_timestamp, "2024-07-01T03:04:00");
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
fn empty_objectives_block_uses_default() {
    let source = "strategy:
  opt:
    objectives:
";
    let result = parse_experiment(source);
    let variant = result.expect("empty objectives block should use the default");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    let objectives = &experiment.strategy.opt.objectives;
    assert_eq!(objectives.len(), 1);
    assert_eq!(objectives[0].metric, BacktestMetric::ExcessSharpe);
    assert_eq!(objectives[0].weight, 1.0);
}

#[test]
fn missing_action_weights_uses_defaults() {
    let variant = parse_experiment(MINIMAL_SOURCE).expect("minimal source should parse");
    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert!(experiment.strategy.opt.action_weights.is_empty());
}

#[test]
fn empty_action_weights_uses_defaults() {
    let source = "strategy:\n  opt:\n    action_weights:";
    let variant = parse_experiment(source).expect("empty action weights should use defaults");
    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert!(experiment.strategy.opt.action_weights.is_empty());
}

#[test]
fn allows_zero_action_weight() {
    let source = "action_weights:\n  next_feat: 0.0";
    let actions_list = vec![Action::NextFeat, Action::SetFeat];
    let opt = parse_opt_source(source, &actions_list).expect("zero action weight should parse");
    assert_eq!(opt.action_weights[&Action::NextFeat], 0.0);
}

#[test]
fn rejects_invalid_action_weight_labels() {
    let actions_list = vec![Action::NextFeat, Action::SetFeat];

    for label in ["missing", "set_true_idx", "set_input"] {
        let source = format!("action_weights:\n  {label}: 1.0");
        let error = parse_opt_source(&source, &actions_list).unwrap_err();
        assert_eq!(error, format!("invalid action weight label: {label}"));
    }
}

#[test]
fn rejects_invalid_action_weight_values() {
    let actions_list = vec![Action::NextFeat, Action::SetFeat];

    for weight in ["-1.0", "NaN"] {
        let source = format!("action_weights:\n  next_feat: {weight}");
        let error = parse_opt_source(&source, &actions_list).unwrap_err();
        assert_eq!(error, "action weight next_feat must be finite and >= 0.0");
    }
}

#[test]
fn rejects_malformed_action_weight_values() {
    let actions_list = vec![Action::NextFeat, Action::SetFeat];
    let missing_error = parse_opt_source("action_weights:\n  next_feat:", &actions_list).unwrap_err();
    assert_eq!(missing_error, "action weight next_feat must have a value");

    let invalid_error = parse_opt_source("action_weights:\n  next_feat: high", &actions_list).unwrap_err();
    assert_eq!(invalid_error, "invalid action weight: high");
}

#[test]
fn rejects_duplicate_action_weights() {
    let source = "action_weights:\n  next_feat: 1.0\n  next_feat: 2.0";
    let actions_list = vec![Action::NextFeat, Action::SetFeat];
    let error = parse_opt_source(source, &actions_list).unwrap_err();
    assert_eq!(error, "duplicate action weight: next_feat");
}

#[test]
fn rejects_all_zero_action_weights() {
    let source = "action_weights:\n  next_feat: 0.0\n  set_feat: 0.0";
    let actions_list = vec![Action::NextFeat, Action::SetFeat];
    let error = parse_opt_source(source, &actions_list).unwrap_err();
    assert_eq!(error, "at least one action weight must be > 0.0");
}

#[test]
fn uses_feature_specific_threshold_defaults() {
    let source = "strategy:
  base_net:
    type: logic
  feats:
    constant:
      feature: constant
      constant: 2.0
    raw_returns:
      feature: raw_returns
    normalized_sma:
      feature: normalized_sma
    normalized_ema:
      feature: normalized_ema
    macd_line:
      feature: normalized_macd
      output: line
    macd_signal:
      feature: normalized_macd
      output: signal
    macd_hist:
      feature: normalized_macd
      output: hist
    rsi:
      feature: rsi
    bb_upper:
      feature: normalized_bb
      output: upper
    bb_lower:
      feature: normalized_bb
      output: lower
    bb_width:
      feature: normalized_bb
      output: width
    stochastic_k:
      feature: stochastic
      output: percent_k
    stochastic_d:
      feature: stochastic
      output: percent_d
    normalized_atr:
      feature: normalized_atr
    roc:
      feature: roc
    dc_upper:
      feature: normalized_dc
      output: upper
    dc_lower:
      feature: normalized_dc
      output: lower
    dc_middle:
      feature: normalized_dc
      output: middle
    dc_width:
      feature: normalized_dc
      output: width
  actions:
    type: logic
";
    let variant = parse_experiment(source).expect("feature threshold defaults should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    let thresholds = &experiment.strategy.actions.thresholds;
    let expected_ranges = [
        ("constant", 1.5, 2.5),
        ("raw_returns", -0.1, 0.1),
        ("normalized_sma", 0.9, 1.1),
        ("normalized_ema", 0.9, 1.1),
        ("macd_line", -0.1, 0.1),
        ("macd_signal", -0.1, 0.1),
        ("macd_hist", -0.1, 0.1),
        ("rsi", 0.0, 100.0),
        ("bb_upper", 0.9, 1.1),
        ("bb_lower", 0.9, 1.1),
        ("bb_width", 0.0, 0.2),
        ("stochastic_k", 0.0, 100.0),
        ("stochastic_d", 0.0, 100.0),
        ("normalized_atr", 0.0, 0.1),
        ("roc", 0.9, 1.1),
        ("dc_upper", 0.9, 1.1),
        ("dc_lower", 0.9, 1.1),
        ("dc_middle", 0.9, 1.1),
        ("dc_width", 0.0, 0.2)
    ];

    for (feat_id, expected_min, expected_max) in expected_ranges {
        let range = &thresholds[feat_id];
        assert_eq!(range.min, expected_min);
        assert_eq!(range.max, expected_max);
    }
}

#[test]
fn explicit_threshold_bounds_override_feature_defaults_independently() {
    let source = "strategy:
  base_net:
    type: logic
  feats:
    min_only:
      feature: rsi
    max_only:
      feature: rsi
    both:
      feature: rsi
    omitted:
      feature: rsi
  actions:
    type: logic
    thresholds:
      min_only:
        min: 25.0
      max_only:
        max: 75.0
      both:
        min: 10.0
        max: 90.0
";
    let variant = parse_experiment(source).expect("explicit threshold bounds should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    let thresholds = &experiment.strategy.actions.thresholds;
    assert_eq!(thresholds["min_only"].min, 25.0);
    assert_eq!(thresholds["min_only"].max, 100.0);
    assert_eq!(thresholds["max_only"].min, 0.0);
    assert_eq!(thresholds["max_only"].max, 75.0);
    assert_eq!(thresholds["both"].min, 10.0);
    assert_eq!(thresholds["both"].max, 90.0);
    assert_eq!(thresholds["omitted"].min, 0.0);
    assert_eq!(thresholds["omitted"].max, 100.0);
}

#[test]
fn empty_source_uses_defaults() {
    let variant = parse_experiment("strategy:\n  base_net:\n    type: logic").expect("defaults should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.cv_folds, 5);
    assert_eq!(experiment.symbol, "BTC_USDT");
    assert_eq!(experiment.time_interval, TimeInterval::OneHour);
    assert_eq!(experiment.val_size, 0.2);
    assert_eq!(experiment.test_size, 0.2);
    assert_eq!(experiment.backtest_schema.metrics.len(), 1);
    assert_eq!(experiment.strategy.qty, 0.01);
    assert_eq!(experiment.strategy.exit_schema.stop_loss, 0.04);
    assert_eq!(experiment.strategy.exit_schema.take_profit, 0.08);
    assert_eq!(experiment.strategy.exit_schema.max_hold_time, 72);
    assert_eq!(experiment.strategy.actions.allowed_gates.len(), 3);
    assert!(!experiment.strategy.entry_schema.strong_entry_long);
    assert!(!experiment.strategy.exit_schema.strong_exit_long);
}

#[test]
fn parses_interval_alias() {
    let source = "interval: 1h\nstrategy:\n  base_net:\n    type: logic";
    let variant = parse_experiment(source).expect("interval alias should parse");

    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };

    assert_eq!(experiment.time_interval, TimeInterval::OneHour);
}

#[test]
fn rejects_invalid_time_interval() {
    let source = "time_interval: 4h\nstrategy:\n  base_net:\n    type: logic";
    let error = match parse_experiment(source) {
        Ok(_) => panic!("invalid interval should fail"),
        Err(error) => error
    };

    assert_eq!(error, "time_interval must be 1h");
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
fn missing_feat_order_uses_feature_ids_in_order() {
    for net_type in ["logic", "decision"] {
        let source = format!("strategy:
  base_net:
    type: {net_type}
  feats:
    feat_a:
      feature: rsi
    feat_b:
      feature: roc
  actions:
    type: {net_type}
");
        let result = parse_experiment(&source);
        let variant = result.expect("missing feat_order should use all feature ids");
        let feat_order = match variant {
            ExperimentVariant::Logic(experiment) => experiment.strategy.actions.feat_order,
            ExperimentVariant::Decision(experiment) => experiment.strategy.actions.feat_order
        };

        assert_eq!(feat_order, vec!["feat_a".to_string(), "feat_b".to_string()]);
    }
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
    assert_eq!(error, "invalid metric: []");
}

#[test]
fn rejects_inline_meta_actions_block() {
    let source = "strategy:\n  actions:\n    meta_actions: []";
    let result = parse_experiment(source);
    let Err(error) = result else {
        panic!("inline meta_actions should fail");
    };
    assert_eq!(error, "meta_actions must be a nested block");
}

#[test]
fn rejects_cv_folds_over_cap() {
    let source = "cv_folds: 11\nstrategy:\n  base_net:\n    type: logic";
    let result = parse_experiment(source);
    let Err(error) = result else {
        panic!("cv_folds over cap should fail");
    };
    assert!(error.contains("cv_folds must be <= 10"));
}

#[test]
fn accepts_cv_folds_at_cap() {
    let source = "cv_folds: 10\nstrategy:\n  base_net:\n    type: logic";
    parse_experiment(source).expect("cv_folds at cap should parse");
}

#[test]
fn rejects_max_trail_len_over_cap() {
    let source = DECISION_SOURCE.replace("max_trail_len: 6", "max_trail_len: 26");
    let result = parse_experiment(&source);
    let Err(error) = result else {
        panic!("max_trail_len over cap should fail");
    };
    assert!(error.contains("max_trail_len must be <= 25"));
}

#[test]
fn accepts_max_trail_len_at_cap() {
    let source = DECISION_SOURCE.replace("max_trail_len: 6", "max_trail_len: 25");
    parse_experiment(&source).expect("max_trail_len at cap should parse");
}

fn logic_source_with_feats(count: usize) -> String {
    let mut feats = String::new();
    let mut thresholds = String::new();
    for i in 0..count {
        let feat_line = format!("    f{i}:\n      feature: rsi\n      window: 14\n");
        feats.push_str(&feat_line);
        let threshold_line = format!("      f{i}:\n        min: 0.0\n        max: 1.0\n");
        thresholds.push_str(&threshold_line);
    }
    format!("strategy:\n  base_net:\n    type: logic\n  feats:\n{feats}  actions:\n    type: logic\n    thresholds:\n{thresholds}")
}

#[test]
fn rejects_features_over_cap() {
    let source = logic_source_with_feats(26);
    let result = parse_experiment(&source);
    let Err(error) = result else {
        panic!("features over cap should fail");
    };
    assert!(error.contains("Cannot have more than 25 features"));
}

#[test]
fn accepts_features_at_cap() {
    let source = logic_source_with_feats(25);
    parse_experiment(&source).expect("features at cap should parse");
}

#[test]
fn scalar_fields_require_inline_values() {
    let source = "string:\noption_string:\nf64:\noption_f64:\nusize:\noption_usize:\nbool:";
    let lines = to_lines(source);
    let fields = Fields::from_lines(&lines).expect("fields should parse");

    assert_eq!(fields.string(&["string"], "default").unwrap_err(), "string must have an inline value");
    assert_eq!(fields.option_string(&["option_string"]).unwrap_err(), "option_string must have an inline value");
    assert_eq!(fields.f64(&["f64"], 1.0).unwrap_err(), "f64 must have an inline value");
    assert_eq!(fields.option_f64(&["option_f64"]).unwrap_err(), "option_f64 must have an inline value");
    assert_eq!(fields.usize(&["usize"], 1).unwrap_err(), "usize must have an inline value");
    assert_eq!(fields.option_usize(&["option_usize"]).unwrap_err(), "option_usize must have an inline value");
    assert_eq!(fields.bool(&["bool"], false).unwrap_err(), "bool must have an inline value");
}

#[test]
fn missing_string_list_uses_default() {
    let lines = to_lines("");
    let fields = Fields::from_lines(&lines).expect("fields should parse");
    let default = vec!["first".to_string(), "second".to_string()];

    assert_eq!(fields.string_list(&["items"], default.clone()).expect("default should be returned"), default);
}

#[test]
fn child_fields_distinguishes_missing_present_and_invalid() {
    let lines = to_lines("parent:\n  child: value");
    let fields = Fields::from_lines(&lines).expect("fields should parse");
    let missing_fields = fields.child_fields(&["missing"]).expect("missing child should not error");
    let child_fields = fields.child_fields(&["parent"]).expect("present child should parse").expect("present child should exist");

    assert!(missing_fields.is_none());
    assert_eq!(child_fields.string(&["child"], "").expect("child value should parse"), "value");

    let invalid_lines = to_lines("parent:\n  child");
    let invalid_fields = Fields::from_lines(&invalid_lines).expect("parent fields should parse");
    let error = match invalid_fields.child_fields(&["parent"]) {
        Ok(_) => panic!("invalid child should fail"),
        Err(error) => error
    };

    assert_eq!(error, "Line is missing colon");

    let inline_lines = to_lines("parent: value");
    let inline_fields = Fields::from_lines(&inline_lines).expect("fields should parse");
    let error = match inline_fields.child_fields(&["parent"]) {
        Ok(_) => panic!("inline child block should fail"),
        Err(error) => error
    };

    assert_eq!(error, "parent must be a nested block");
}

#[test]
fn missing_child_blocks_use_parser_defaults() {
    let variant = parse_experiment("").expect("missing child blocks should use parser defaults");
    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("default network should be logic");
    };

    assert_eq!(experiment.backtest_schema.start_offset, 50);
    assert_eq!(experiment.backtest_schema.start_balance, 1000.0);
    assert_eq!(experiment.backtest_schema.metrics.len(), 1);
    assert!(experiment.strategy.base_net.nodes.is_empty());
    assert!(experiment.strategy.feats.is_empty());
}
