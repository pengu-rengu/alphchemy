use alphchemy::actions::actions::Action;
use alphchemy::actions::logic_actions::LogicActions;
use alphchemy::experiment::backtest::{BacktestMetric, BacktestSchema, backtest};
use alphchemy::experiment::experiment::{Experiment, FoldResults, get_folds};
use alphchemy::experiment::strategy::{NetSignals, Strategy};
use alphchemy::experiment::tojson::fold_results_json;
use alphchemy::features::features::{Constant, Feature, TimestampedTable};
use alphchemy::network::logic_net::{Gate, InputNode, LogicNet, LogicNode, LogicPenalties};
use alphchemy::network::network::{Anchor, NodePtr};
use alphchemy::optimizer::genetic::GeneticOpt;
use alphchemy::optimizer::optimizer::{ItersState, StopConds};
use alphchemy::parse::parse_experiment::run_experiment_source;
use serde_json::json;
use std::collections::HashMap;

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
fn get_folds_distributes_remainder_to_reach_final_bar() {
    let net = LogicNet {
        nodes: vec![LogicNode::Input(InputNode {
            threshold: Some(0.0),
            feat_id: Some("signal".to_string()),
            value: false
        })],
        default_value: false
    };
    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: HashMap::new(),
        feat_order: vec!["signal".to_string()],
        n_thresholds: 1,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And]
    };
    let penalties = LogicPenalties {
        node: 0.0,
        input: 0.0,
        gate: 0.0,
        recurrence: 0.0,
        feedforward: 0.0,
        used_feat: 0.0,
        unused_feat: 0.0
    };
    let stop_conds = StopConds {
        max_iters: 1,
        train_patience: 1,
        val_patience: 1
    };
    let opt = GeneticOpt {
        pop_size: 1,
        seq_len: 1,
        n_elites: 0,
        mut_rate: 0.0,
        cross_rate: 0.0,
        tourn_size: 1,
        objectives: Vec::new(),
        random_seed: Some(1)
    };
    let node_ptr = NodePtr { anchor: Anchor::FromStart, idx: 0 };
    let strategy = Strategy {
        base_net: net,
        feats: vec![Feature::Constant(Constant {
            id: "signal".to_string(),
            constant: 1.0
        })],
        actions,
        penalties,
        stop_conds,
        opt,
        entry_ptr: node_ptr.clone(),
        exit_ptr: node_ptr,
        stop_loss: 0.1,
        take_profit: 0.1,
        max_hold_time: 1,
        qty: 1.0
    };
    let experiment = Experiment {
        val_size: 0.2,
        test_size: 0.4,
        cv_folds: 3,
        fold_size: 0.5,
        symbol: "BTC_USDT".to_string(),
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

    let folds = get_folds(&experiment, &close, &feat_table);
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
    let results = backtest(signals, 1.0, 0.1, 0.1, 1, &schema, &close_prices);
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
