use alphchemy::experiment::experiment::run_experiment_json;
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
        "start_timestamp": 2.0,
        "end_timestamp": 1.0
    });

    let result = run_experiment_json(&experiment).await;

    assert_eq!(result["is_internal"], false);
    assert_eq!(result["error"], "start_timestamp must be < end_timestamp");
}
