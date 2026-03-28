use alphchemy::test_utils::generate_ohlc_data;
use alphchemy::features::features::{feat_matrix, parse_feats};
use alphchemy::experiment::experiment::{
    get_folds, run_experiment, run_experiment_json,
    parse_experiment, ExperimentVariant
};

fn experiment_json() -> serde_json::Value {
    serde_json::json!({
        "val_size": 0.15,
        "test_size": 0.15,
        "cv_folds": 3,
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
                "max_iters": 2,
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
                    "node_ptr": { "anchor": "from_end", "idx": 0 },
                    "position_size": 0.1,
                    "max_positions": 3
                }
            ],
            "exit_schemas": [
                {
                    "node_ptr": { "anchor": "from_end", "idx": 0 },
                    "entry_indices": [0],
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
                        "feat_idx": 0
                    }
                ],
                "default_value": false
            },
            "actions": {
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

fn feats_json() -> Vec<serde_json::Value> {
    vec![serde_json::json!({
        "feature": "constant",
        "id": "const_1",
        "constant": 1.0
    })]
}

#[test]
fn test_get_folds_count() {
    let json = experiment_json();
    let experiment = match parse_experiment(&json).unwrap() {
        ExperimentVariant::Logic(exp) => exp,
        _ => panic!("expected logic experiment")
    };

    let (_close_vec, ohlc) = generate_ohlc_data(200);
    let close = ohlc.get("close").unwrap();
    let close_slice = close.as_slice().unwrap();
    let feats = parse_feats(&feats_json()).unwrap();
    let full_matrix = feat_matrix(&feats, &ohlc);
    let folds = get_folds(&experiment, close_slice, &full_matrix);

    assert_eq!(folds.len(), 3);
}

#[test]
fn test_fold_slices_are_contiguous() {
    let json = experiment_json();
    let experiment = match parse_experiment(&json).unwrap() {
        ExperimentVariant::Logic(exp) => exp,
        _ => panic!("expected logic experiment")
    };

    let (_close_vec, ohlc) = generate_ohlc_data(200);
    let close = ohlc.get("close").unwrap();
    let close_slice = close.as_slice().unwrap();
    let feats = parse_feats(&feats_json()).unwrap();
    let full_matrix = feat_matrix(&feats, &ohlc);
    let folds = get_folds(&experiment, close_slice, &full_matrix);

    for fold in &folds {
        let train_len = fold.train_close.len();
        let val_len = fold.val_close.len();
        let test_len = fold.test_close.len();
        let total = train_len + val_len + test_len;
        let expected = fold.end_idx - fold.start_idx + 1;

        assert_eq!(total, expected);
        assert!(train_len > 0);
        assert!(val_len > 0);
        assert!(test_len > 0);
    }
}

#[test]
fn test_fold_slices_match_original_data() {
    let (_close_vec, ohlc) = generate_ohlc_data(200);
    let close = ohlc.get("close").unwrap();
    let close_slice = close.as_slice().unwrap();
    let feats = parse_feats(&feats_json()).unwrap();
    let full_matrix = feat_matrix(&feats, &ohlc);

    let json = experiment_json();
    let experiment = match parse_experiment(&json).unwrap() {
        ExperimentVariant::Logic(exp) => exp,
        _ => panic!("expected logic experiment")
    };

    let folds = get_folds(&experiment, close_slice, &full_matrix);

    for fold in &folds {
        let first_train = fold.train_close[0];
        let expected = close_slice[fold.start_idx];
        assert_eq!(first_train, expected);

        let last_test = fold.test_close[fold.test_close.len() - 1];
        let expected_last = close_slice[fold.end_idx];
        assert_eq!(last_test, expected_last);
    }
}

#[test]
fn test_fold_feat_matrix_rows_match_close_len() {
    let (_close_vec, ohlc) = generate_ohlc_data(200);
    let close = ohlc.get("close").unwrap();
    let close_slice = close.as_slice().unwrap();
    let feats = parse_feats(&feats_json()).unwrap();
    let full_matrix = feat_matrix(&feats, &ohlc);

    let json = experiment_json();
    let experiment = match parse_experiment(&json).unwrap() {
        ExperimentVariant::Logic(exp) => exp,
        _ => panic!("expected logic experiment")
    };

    let folds = get_folds(&experiment, close_slice, &full_matrix);

    for fold in &folds {
        assert_eq!(fold.train_feat_matrix.nrows(), fold.train_close.len());
        assert_eq!(fold.val_feat_matrix.nrows(), fold.val_close.len());
        assert_eq!(fold.test_feat_matrix.nrows(), fold.test_close.len());
    }
}

#[test]
fn test_fold_feat_matrix_shares_original_data() {
    let (_close_vec, ohlc) = generate_ohlc_data(200);
    let close = ohlc.get("close").unwrap();
    let close_slice = close.as_slice().unwrap();
    let feats = parse_feats(&feats_json()).unwrap();
    let full_matrix = feat_matrix(&feats, &ohlc);

    let json = experiment_json();
    let experiment = match parse_experiment(&json).unwrap() {
        ExperimentVariant::Logic(exp) => exp,
        _ => panic!("expected logic experiment")
    };

    let folds = get_folds(&experiment, close_slice, &full_matrix);

    for fold in &folds {
        let first_row = fold.train_feat_matrix.row(0);
        let expected_row = full_matrix.row(fold.start_idx);
        assert_eq!(first_row, expected_row);
    }
}

#[test]
fn test_single_fold() {
    let mut json = experiment_json();
    json["cv_folds"] = serde_json::json!(1);
    json["fold_size"] = serde_json::json!(1.0);

    let experiment = match parse_experiment(&json).unwrap() {
        ExperimentVariant::Logic(exp) => exp,
        _ => panic!("expected logic experiment")
    };

    let (_close_vec, ohlc) = generate_ohlc_data(200);
    let close = ohlc.get("close").unwrap();
    let close_slice = close.as_slice().unwrap();
    let feats = parse_feats(&feats_json()).unwrap();
    let full_matrix = feat_matrix(&feats, &ohlc);
    let folds = get_folds(&experiment, close_slice, &full_matrix);

    assert_eq!(folds.len(), 1);
    let fold = &folds[0];
    assert_eq!(fold.start_idx, 0);
    assert_eq!(fold.end_idx, 199);
}

#[test]
fn test_run_experiment_returns_results() {
    let json = experiment_json();
    let experiment = match parse_experiment(&json).unwrap() {
        ExperimentVariant::Logic(exp) => exp,
        _ => panic!("expected logic experiment")
    };

    let (_close_vec, ohlc) = generate_ohlc_data(200);
    let results = run_experiment(&experiment, &ohlc);

    assert_eq!(results.fold_results.len(), 3);
    assert!(results.invalid_frac >= 0.0);
    assert!(results.invalid_frac <= 1.0);
}

#[test]
fn test_run_experiment_json_no_error() {
    let json = experiment_json();
    let (_close_vec, ohlc) = generate_ohlc_data(200);
    let result = run_experiment_json(&json, &ohlc);

    assert!(result.get("error").is_none());
}
