use alphchemy_engine::actions::actions::Action;
use alphchemy_engine::actions::logic_actions::LogicActions;
use alphchemy_engine::experiment::backtest::{BacktestMetric, BacktestSchema, backtest};
use alphchemy_engine::experiment::experiment::{Experiment, ExperimentVariant, FoldResults, TimeInterval};
use alphchemy_engine::experiment::strategy::{NetSignals, Strategy};
use alphchemy_engine::experiment::tojson::fold_results_json;
use alphchemy_engine::features::features::TimestampedTable;
use alphchemy_engine::network::logic_net::{LogicNet, LogicPenalties};
use alphchemy_engine::optimizer::optimizer::ItersState;
use alphchemy_experiments::fetch_data::fetch_ohlc;
use alphchemy_experiments::run_experiment_source;
use alphchemy_parse::parse::parse_experiment::parse_experiment;
use serde_json::json;
use std::collections::HashMap;

fn default_strategy() -> Strategy<LogicNet, LogicPenalties, LogicActions> {
    let source = "strategy:\n  base_net:\n    type: logic";
    let variant = parse_experiment(source).expect("default logic strategy should parse");
    let ExperimentVariant::Logic(experiment) = variant else {
        panic!("expected logic experiment");
    };
    experiment.strategy
}

#[tokio::test]
async fn run_experiment_source_invalid_value_returns_user_error() {
    let result = run_experiment_source("val_size: not_a_number").await;

    assert_eq!(result["is_internal"], false);
    assert!(result["error"].is_string());
}

#[tokio::test]
async fn run_experiment_source_invalid_timestamp_order_returns_user_error() {
    let source = "start_timestamp: 2024-01-02T00:00:00Z\nend_timestamp: 2024-01-01T00:00:00Z";

    let result = run_experiment_source(source).await;

    assert_eq!(result["is_internal"], false);
    assert_eq!(result["error"], "start_timestamp must be < end_timestamp");
}

#[test]
fn fetch_ohlc_rejects_range_over_bar_cap() {
    let result = fetch_ohlc("BTC_USDT", "2000-01-01T00:00:00", "2100-01-01T00:00:00");
    let Err(error) = result else {
        panic!("range over bar cap should fail");
    };
    assert!(error.contains("exceeds 50000 bars"));
}

#[test]
fn logic_experiment_json_delegates_to_strategy_and_keeps_action_order() {
    let source = "strategy:
  base_net:
    type: logic
  feats:
    feat_a:
      feature: constant
      constant: 1.0
    feat_b:
      feature: constant
      constant: 2.0
  actions:
    meta_actions:
      zeta:
        sub_actions: next_feat
      alpha:
        sub_actions: next_threshold
    thresholds:
      feat_a:
        min: 0.0
        max: 1.0
      feat_b:
        min: 1.0
        max: 2.0
    feat_order: feat_b, feat_a
";
    let variant = parse_experiment(source).expect("logic source should parse");
    let ExperimentVariant::Logic(experiment) = &variant else {
        panic!("expected logic experiment");
    };

    let strategy_json = experiment.strategy.to_json();
    let experiment_json = experiment.to_json();
    let variant_json = variant.to_json();
    let actions = &strategy_json["actions"];
    let meta_actions = actions["meta_actions"].as_array().expect("meta actions should be an array");
    let thresholds = actions["thresholds"].as_array().expect("thresholds should be an array");

    assert_eq!(experiment_json["strategy"], strategy_json);
    assert_eq!(variant_json, experiment_json);
    assert_eq!(experiment_json["time_interval"], "1h");
    assert!(experiment_json.get("interval").is_none());
    assert_eq!(strategy_json["base_net"]["type"], "logic");
    assert_eq!(actions["type"], "logic");
    assert_eq!(strategy_json["penalties"]["type"], "logic");
    assert_eq!(strategy_json["opt"]["type"], "genetic");
    assert_eq!(strategy_json["entry_ptr"]["offset"], 0);
    assert!(strategy_json["entry_ptr"].get("idx").is_none());
    assert_eq!(strategy_json["strong_entry"], false);
    assert_eq!(strategy_json["strong_exit"], false);
    assert_eq!(meta_actions[0]["label"], "alpha");
    assert_eq!(meta_actions[1]["label"], "zeta");
    assert_eq!(thresholds[0]["feat_id"], "feat_b");
    assert_eq!(thresholds[1]["feat_id"], "feat_a");
}

#[test]
fn decision_experiment_json_keeps_component_tags() {
    let source = "strategy:
  base_net:
    type: decision
  feats:
    feat_a:
      feature: constant
      constant: 1.0
  actions:
    thresholds:
      feat_a:
        min: 0.0
        max: 1.0
    feat_order: feat_a
    allow_refs: true
";
    let variant = parse_experiment(source).expect("decision source should parse");
    let ExperimentVariant::Decision(experiment) = &variant else {
        panic!("expected decision experiment");
    };

    let experiment_json = experiment.to_json();
    let strategy_json = experiment.strategy.to_json();

    assert_eq!(experiment_json["strategy"], strategy_json);
    assert_eq!(strategy_json["base_net"]["type"], "decision");
    assert_eq!(strategy_json["actions"]["type"], "decision");
    assert_eq!(strategy_json["penalties"]["type"], "decision");
    assert_eq!(strategy_json["opt"]["type"], "genetic");
    assert!(strategy_json["base_net"].get("idx_trail").is_none());
}

#[test]
fn get_folds_distributes_remainder_to_reach_final_bar() {
    let strategy = default_strategy();
    let experiment = Experiment {
        val_size: 0.2,
        test_size: 0.4,
        cv_folds: 3,
        fold_size: 0.5,
        symbol: "BTC_USDT".to_string(),
        time_interval: TimeInterval::OneHour,
        start_timestamp: "2024-01-01T00:00:00".to_string(),
        end_timestamp: "2024-01-01T09:00:00".to_string(),
        backtest_schema: BacktestSchema {
            start_offset: 0,
            start_balance: 100.0,
            delay: 0,
            metrics: Vec::new()
        },
        strategy
    };
    let timestamps = (0..10)
        .map(|hour| format!("2024-01-01T{hour:02}:00:00"))
        .collect::<Vec<String>>();
    let close = (0..10).map(|idx| idx as f64).collect::<Vec<f64>>();
    let feat_table = TimestampedTable {
        timestamps,
        table: HashMap::new()
    };

    let folds = experiment.get_folds(&close, &feat_table);
    let final_fold = &folds[2];

    assert_eq!(final_fold.train_start_timestamp, "2024-01-01T04:00:00");
    assert_eq!(final_fold.test_end_timestamp, "2024-01-01T09:00:00");
}

#[test]
fn fold_results_json_includes_best_networks() {
    let schema = BacktestSchema {
        start_offset: 0,
        start_balance: 100.0,
        delay: 0,
        metrics: vec![BacktestMetric::ExcessSharpe]
    };
    let signals = Vec::<NetSignals>::new();
    let close_prices = Vec::<f64>::new();
    let strategy = default_strategy();
    let results = backtest(signals, &strategy, &schema, &close_prices);
    let opt_results = ItersState {
        iters: 1,
        train_improvements: Vec::new(),
        val_improvements: Vec::new(),
        best_train_seq: vec![Action::NewInput],
        best_val_seq: vec![Action::NewGate],
        best_train_score: 1.0,
        best_val_score: 2.0
    };
    let fold = FoldResults {
        train_start_timestamp: "train-start".to_string(),
        train_end_timestamp: "train-end".to_string(),
        val_start_timestamp: "val-start".to_string(),
        val_end_timestamp: "val-end".to_string(),
        test_start_timestamp: "test-start".to_string(),
        test_end_timestamp: "test-end".to_string(),
        train_results: results.clone(),
        val_results: results.clone(),
        test_results: results,
        best_train_net: json!({"nodes": [], "default_value": false}),
        best_val_net: json!({"nodes": [], "default_value": true}),
        opt_results
    };

    let json_results = fold_results_json(&[fold]);
    let opt_json = &json_results[0]["opt_results"];

    assert!(json_results[0].get("start_timestamp").is_none());
    assert!(json_results[0].get("end_timestamp").is_none());
    assert!(opt_json["best_train_net"].get("type").is_none());
    assert_eq!(opt_json["best_train_net"]["default_value"], false);
    assert!(opt_json["best_val_net"].get("type").is_none());
    assert_eq!(opt_json["best_val_net"]["default_value"], true);
}
