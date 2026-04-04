use alphchemy::experiment::experiment::parse_experiment;
use alphchemy::experiment::backtest::parse_backtest_schema;
use alphchemy::optimizer::optimizer::parse_stop_conds;
use alphchemy::optimizer::genetic::parse_opt;
use alphchemy::network::logic_net::parse_logic_net;
use alphchemy::network::decision_net::parse_decision_net;
use alphchemy::utils::{get_field, from_field, std_dev, cmp_f64, expect_non_neg};

fn valid_logic_experiment_json() -> serde_json::Value {
    serde_json::json!({
        "val_size": 0.15,
        "test_size": 0.15,
        "cv_folds": 2,
        "fold_size": 0.5,
        "backtest_schema": {
            "start_offset": 5,
            "start_balance": 10000.0,
            "delay": 1
        },
        "strategy": {
            "global_max_positions": 3,
            "feats": [
                {
                    "feature": "constant",
                    "id": "const_1",
                    "constant": 1.0
                }
            ],
            "stop_conds": {
                "max_iters": 3,
                "train_patience": 5,
                "val_patience": 5
            },
            "opt": {
                "type": "genetic",
                "pop_size": 10,
                "seq_len": 5,
                "n_elites": 2,
                "mut_rate": 0.1,
                "cross_rate": 0.7,
                "tournament_size": 3
            },
            "entry_schemas": [
                {
                    "id": "entry_1",
                    "node_ptr": { "anchor": "from_end", "idx": 0 },
                    "position_size": 0.1,
                    "max_positions": 3
                }
            ],
            "exit_schemas": [
                {
                    "id": "exit_1",
                    "node_ptr": { "anchor": "from_end", "idx": 0 },
                    "entry_ids": ["entry_1"],
                    "stop_loss": 0.05,
                    "take_profit": 0.05,
                    "max_hold_time": 20
                }
            ],
            "base_net": {
                "type": "logic",
                "nodes": [
                    {
                        "type": "input",
                        "threshold": 0.5,
                        "feat_id": "const_1"
                    }
                ],
                "default_value": false
            },
            "actions": {
                "feat_order": ["const_1"],
                "n_thresholds": 5,
                "allow_recurrence": false,
                "allowed_gates": ["and", "or"],
                "meta_actions": [],
                "thresholds": [
                    { "feat_id": "const_1", "min": 0.0, "max": 2.0 }
                ]
            },
            "penalties": {
                "node": 0.0,
                "input": 0.0,
                "gate": 0.0,
                "recurrence": 0.0,
                "feedforward": 0.0,
                "used_feat": 0.0,
                "unused_feat": 0.0
            }
        }
    })
}

fn valid_decision_experiment_json() -> serde_json::Value {
    serde_json::json!({
        "val_size": 0.15,
        "test_size": 0.15,
        "cv_folds": 2,
        "fold_size": 0.5,
        "backtest_schema": {
            "start_offset": 5,
            "start_balance": 10000.0,
            "delay": 1
        },
        "strategy": {
            "global_max_positions": 3,
            "feats": [
                {
                    "feature": "constant",
                    "id": "const_1",
                    "constant": 1.0
                }
            ],
            "stop_conds": {
                "max_iters": 3,
                "train_patience": 5,
                "val_patience": 5
            },
            "opt": {
                "type": "genetic",
                "pop_size": 10,
                "seq_len": 5,
                "n_elites": 2,
                "mut_rate": 0.1,
                "cross_rate": 0.7,
                "tournament_size": 3
            },
            "entry_schemas": [
                {
                    "id": "entry_1",
                    "node_ptr": { "anchor": "from_end", "idx": 0 },
                    "position_size": 0.1,
                    "max_positions": 3
                }
            ],
            "exit_schemas": [
                {
                    "id": "exit_1",
                    "node_ptr": { "anchor": "from_end", "idx": 0 },
                    "entry_ids": ["entry_1"],
                    "stop_loss": 0.05,
                    "take_profit": 0.05,
                    "max_hold_time": 20
                }
            ],
            "base_net": {
                "type": "decision",
                "nodes": [
                    {
                        "type": "branch",
                        "threshold": 0.5,
                        "feat_id": "const_1"
                    }
                ],
                "max_trail_len": 10,
                "default_value": false
            },
            "actions": {
                "feat_order": ["const_1"],
                "n_thresholds": 5,
                "allow_refs": false,
                "meta_actions": [],
                "thresholds": [
                    { "feat_id": "const_1", "min": 0.0, "max": 2.0 }
                ]
            },
            "penalties": {
                "node": 0.0,
                "branch": 0.0,
                "ref": 0.0,
                "leaf": 0.0,
                "non_leaf": 0.0,
                "used_feat": 0.0,
                "unused_feat": 0.0
            }
        }
    })
}

#[test]
fn test_parse_experiment_logic_valid() {
    let json = valid_logic_experiment_json();
    let result = parse_experiment(&json);
    assert!(result.is_ok());
}

#[test]
fn test_parse_experiment_decision_valid() {
    let json = valid_decision_experiment_json();
    let result = parse_experiment(&json);
    assert!(result.is_ok());
}

#[test]
fn test_parse_experiment_empty_json() {
    let json = serde_json::json!({});
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_invalid_val_size() {
    let mut json = valid_logic_experiment_json();
    json["val_size"] = serde_json::json!(-0.1);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_val_test_sum_too_large() {
    let mut json = valid_logic_experiment_json();
    json["val_size"] = serde_json::json!(0.6);
    json["test_size"] = serde_json::json!(0.5);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_zero_cv_folds() {
    let mut json = valid_logic_experiment_json();
    json["cv_folds"] = serde_json::json!(0);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_invalid_fold_size() {
    let mut json = valid_logic_experiment_json();
    json["fold_size"] = serde_json::json!(1.5);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_backtest_schema_valid() {
    let json = serde_json::json!({
        "start_offset": 10,
        "start_balance": 10000.0,
        "delay": 1
    });
    let result = parse_backtest_schema(&json);
    assert!(result.is_ok());
}

#[test]
fn test_parse_backtest_schema_invalid_balance() {
    let json = serde_json::json!({
        "start_offset": 10,
        "start_balance": -100.0,
        "delay": 1
    });
    let result = parse_backtest_schema(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_stop_conds_valid() {
    let json = serde_json::json!({
        "max_iters": 100,
        "train_patience": 10,
        "val_patience": 10
    });
    let result = parse_stop_conds(&json);
    assert!(result.is_ok());
}

#[test]
fn test_parse_stop_conds_zero_max_iters() {
    let json = serde_json::json!({
        "max_iters": 0,
        "train_patience": 10,
        "val_patience": 10
    });
    let result = parse_stop_conds(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_opt_valid() {
    let json = serde_json::json!({
        "type": "genetic",
        "pop_size": 20,
        "seq_len": 10,
        "n_elites": 2,
        "mut_rate": 0.1,
        "cross_rate": 0.7,
        "tournament_size": 3
    });
    let result = parse_opt(&json);
    assert!(result.is_ok());
}

#[test]
fn test_parse_opt_wrong_type() {
    let json = serde_json::json!({
        "type": "unknown",
        "pop_size": 20,
        "seq_len": 10,
        "n_elites": 2,
        "mut_rate": 0.1,
        "cross_rate": 0.7,
        "tournament_size": 3
    });
    let result = parse_opt(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_opt_zero_pop_size() {
    let json = serde_json::json!({
        "type": "genetic",
        "pop_size": 0,
        "seq_len": 10,
        "n_elites": 0,
        "mut_rate": 0.1,
        "cross_rate": 0.7,
        "tournament_size": 1
    });
    let result = parse_opt(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_opt_invalid_mut_rate() {
    let json = serde_json::json!({
        "type": "genetic",
        "pop_size": 20,
        "seq_len": 10,
        "n_elites": 2,
        "mut_rate": 1.5,
        "cross_rate": 0.7,
        "tournament_size": 3
    });
    let result = parse_opt(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_logic_net_valid() {
    let json = serde_json::json!({
        "nodes": [
            { "type": "input", "threshold": 0.5, "feat_id": "feat_a" },
            { "type": "gate", "gate": "and", "in1_idx": 0, "in2_idx": 0 }
        ],
        "default_value": false
    });
    let feat_ids = vec!["feat_a".to_string(), "feat_b".to_string()];
    let result = parse_logic_net(&json, &feat_ids);
    assert!(result.is_ok());
}

#[test]
fn test_parse_logic_net_feat_idx_rejected() {
    let json = serde_json::json!({
        "nodes": [
            { "type": "input", "threshold": 0.5, "feat_idx": 5 }
        ],
        "default_value": false
    });
    let feat_ids = vec!["feat_a".to_string(), "feat_b".to_string()];
    let result = parse_logic_net(&json, &feat_ids);
    assert!(result.is_err());
}

#[test]
fn test_parse_decision_net_valid() {
    let json = serde_json::json!({
        "nodes": [
            { "type": "branch", "threshold": 0.5, "feat_id": "feat_a" }
        ],
        "max_trail_len": 10,
        "default_value": false
    });
    let feat_ids = vec!["feat_a".to_string(), "feat_b".to_string()];
    let result = parse_decision_net(&json, &feat_ids);
    assert!(result.is_ok());
}

#[test]
fn test_parse_decision_net_zero_trail_len() {
    let json = serde_json::json!({
        "nodes": [
            { "type": "branch", "threshold": 0.5, "feat_id": "feat_a" }
        ],
        "max_trail_len": 0,
        "default_value": false
    });
    let feat_ids = vec!["feat_a".to_string(), "feat_b".to_string()];
    let result = parse_decision_net(&json, &feat_ids);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_empty_entry_schemas() {
    let mut json = valid_logic_experiment_json();
    json["strategy"]["entry_schemas"] = serde_json::json!([]);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_duplicate_entry_schema_ids() {
    let mut json = valid_logic_experiment_json();
    json["strategy"]["entry_schemas"] = serde_json::json!([
        {
            "id": "entry_1",
            "node_ptr": { "anchor": "from_end", "idx": 0 },
            "position_size": 0.1,
            "max_positions": 3
        },
        {
            "id": "entry_1",
            "node_ptr": { "anchor": "from_end", "idx": 0 },
            "position_size": 0.1,
            "max_positions": 3
        }
    ]);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_unknown_exit_entry_id() {
    let mut json = valid_logic_experiment_json();
    json["strategy"]["exit_schemas"] = serde_json::json!([
        {
            "id": "exit_1",
            "node_ptr": { "anchor": "from_end", "idx": 0 },
            "entry_ids": ["missing_entry"],
            "stop_loss": 0.05,
            "take_profit": 0.05,
            "max_hold_time": 20
        }
    ]);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_invalid_position_size() {
    let mut json = valid_logic_experiment_json();
    json["strategy"]["entry_schemas"] = serde_json::json!([
        {
            "id": "entry_1",
            "node_ptr": { "anchor": "from_end", "idx": 0 },
            "position_size": 0.0,
            "max_positions": 3
        }
    ]);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_missing_global_max_positions() {
    let mut json = valid_logic_experiment_json();
    json["strategy"].as_object_mut().unwrap().remove("global_max_positions");
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_parse_experiment_zero_global_max_positions() {
    let mut json = valid_logic_experiment_json();
    json["strategy"]["global_max_positions"] = serde_json::json!(0);
    let result = parse_experiment(&json);
    assert!(result.is_err());
}

#[test]
fn test_get_field_present() {
    let json = serde_json::json!({ "foo": 42 });
    let result = get_field(&json, "foo");
    assert!(result.is_ok());
}

#[test]
fn test_get_field_missing() {
    let json = serde_json::json!({ "foo": 42 });
    let result = get_field(&json, "bar");
    assert!(result.is_err());
}

#[test]
fn test_from_field_valid() {
    let json = serde_json::json!({ "count": 5 });
    let result = from_field::<usize>(&json, "count");
    assert_eq!(result.unwrap(), 5);
}

#[test]
fn test_from_field_wrong_type() {
    let json = serde_json::json!({ "count": "not a number" });
    let result = from_field::<usize>(&json, "count");
    assert!(result.is_err());
}

#[test]
fn test_std_dev_empty() {
    assert_eq!(std_dev(&[]), 0.0);
}

#[test]
fn test_std_dev_single() {
    assert_eq!(std_dev(&[5.0]), 0.0);
}

#[test]
fn test_std_dev_known_values() {
    let values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
    let sd = std_dev(&values);
    assert!((sd - 2.138).abs() < 0.01);
}

#[test]
fn test_cmp_f64_ordering() {
    assert_eq!(cmp_f64(1.0, 2.0), std::cmp::Ordering::Less);
    assert_eq!(cmp_f64(2.0, 1.0), std::cmp::Ordering::Greater);
    assert_eq!(cmp_f64(1.0, 1.0), std::cmp::Ordering::Equal);
}

#[test]
fn test_cmp_f64_nan() {
    assert_eq!(cmp_f64(f64::NAN, 1.0), std::cmp::Ordering::Equal);
}

#[test]
fn test_expect_non_neg_valid() {
    assert!(expect_non_neg(0.0, "test").is_ok());
    assert!(expect_non_neg(1.0, "test").is_ok());
}

#[test]
fn test_expect_non_neg_negative() {
    assert!(expect_non_neg(-0.1, "test").is_err());
}
