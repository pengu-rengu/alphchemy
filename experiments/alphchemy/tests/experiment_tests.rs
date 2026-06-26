use alphchemy::actions::actions::Action;
use alphchemy::experiment::backtest::{BacktestMetric, BacktestSchema, backtest};
use alphchemy::experiment::experiment::{FoldResults, run_experiment_json};
use alphchemy::experiment::strategy::NetSignals;
use alphchemy::experiment::tojson::fold_results_json;
use alphchemy::optimizer::optimizer::ItersState;
use serde_json::json;

#[tokio::test]
async fn run_experiment_json_missing_fields_returns_user_error() {
    let result = run_experiment_json(&json!({})).await;

    assert_eq!(result["is_internal"], false);
    assert!(result["error"].is_string());
}

#[tokio::test]
async fn run_experiment_json_invalid_timestamp_order_returns_user_error() {
    let experiment = json!({
        "val_size": 0.2,
        "test_size": 0.2,
        "cv_folds": 1,
        "fold_size": 1.0,
        "start_timestamp": "2024-01-02T00:00:00Z",
        "end_timestamp": "2024-01-01T00:00:00Z",
        "backtest_schema": {},
        "strategy": {}
    });

    let result = run_experiment_json(&experiment).await;

    assert_eq!(result["is_internal"], false);
    assert_eq!(result["error"], "start_timestamp must be < end_timestamp");
}

#[test]
fn fold_results_json_includes_best_networks() {
    let schema = BacktestSchema {
        start_offset: 0,
        start_balance: 100.0,
        delay: 0,
        metrics: vec![BacktestMetric::ExcessSharpe],
        opt_metric: BacktestMetric::ExcessSharpe
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
        start_timestamp: "start".to_string(),
        end_timestamp: "end".to_string(),
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

    assert!(opt_json["best_train_net"].get("type").is_none());
    assert_eq!(opt_json["best_train_net"]["default_value"], false);
    assert!(opt_json["best_val_net"].get("type").is_none());
    assert_eq!(opt_json["best_val_net"]["default_value"], true);
}
