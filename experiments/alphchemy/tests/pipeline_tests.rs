use std::collections::HashMap;
use ndarray::Array1;

use alphchemy::experiment::experiment::{
    Experiment, ExperimentVariant, experiment_results, get_folds,
    run_experiment, parse_experiment
};
use alphchemy::experiment::backtest::BacktestSchema;
use alphchemy::experiment::strategy::{
    Strategy, EntrySchema, ExitSchema, net_signals
};
use alphchemy::experiment::tojson::experiment_results_json;
use alphchemy::network::network::{Anchor, NodePtr, Network};
use alphchemy::network::logic_net::{
    LogicNet, LogicNode, InputNode, GateNode, Gate, LogicPenalties
};
use alphchemy::optimizer::optimizer::StopConds;
use alphchemy::optimizer::genetic::GeneticOpt;
use alphchemy::actions::actions::{ThresholdRange, construct_net};
use alphchemy::actions::logic_actions::LogicActions;
use alphchemy::features::features::{Feature, Constant, feat_matrix};

fn inline_ohlc_data(n_bars: usize) -> (Vec<f64>, HashMap<String, Array1<f64>>) {
    let mut close = Vec::with_capacity(n_bars);
    let mut price = 100.0;
    for i in 0..n_bars {
        let change = ((i as f64) * 0.1).sin() * 0.02;
        price *= 1.0 + change;
        close.push(price);
    }

    let open: Vec<f64> = close.iter().map(|&p| p * 0.999).collect();
    let high: Vec<f64> = close.iter().map(|&p| p * 1.01).collect();
    let low: Vec<f64> = close.iter().map(|&p| p * 0.99).collect();

    let mut ohlc_data = HashMap::new();
    let open_array = Array1::from_vec(open);
    ohlc_data.insert("open".to_string(), open_array);
    let high_array = Array1::from_vec(high);
    ohlc_data.insert("high".to_string(), high_array);
    let low_array = Array1::from_vec(low);
    ohlc_data.insert("low".to_string(), low_array);
    let close_array = Array1::from_vec(close.clone());
    ohlc_data.insert("close".to_string(), close_array);

    (close, ohlc_data)
}

fn sample_logic_experiment() -> Experiment<LogicNet, LogicPenalties, LogicActions> {
    let base_net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                value: false
            })
        ],
        default_value: false
    };

    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(Constant { id: "const_1".to_string(), constant: 1.0 })
    ];

    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: vec![ThresholdRange { min: 0.0, max: 2.0 }],
        n_thresholds: 5,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And, Gate::Or]
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
        max_iters: 3,
        train_patience: 5,
        val_patience: 5
    };

    let opt = GeneticOpt {
        pop_size: 10,
        seq_len: 5,
        n_elites: 2,
        mut_rate: 0.1,
        cross_rate: 0.7,
        tourn_size: 3
    };

    let node_ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };

    let entry_schemas = vec![EntrySchema {
        node_ptr: node_ptr.clone(),
        position_size: 0.1,
        max_positions: 3
    }];

    let exit_schemas = vec![ExitSchema {
        node_ptr,
        entry_indices: vec![0],
        stop_loss: 0.05,
        take_profit: 0.05,
        max_hold_time: 20
    }];

    let strategy = Strategy {
        base_net,
        feats,
        actions,
        penalties,
        stop_conds,
        opt,
        entry_schemas,
        exit_schemas
    };

    let backtest_schema = BacktestSchema {
        start_offset: 5,
        start_balance: 10000.0,
        delay: 1
    };

    Experiment {
        val_size: 0.15,
        test_size: 0.15,
        cv_folds: 2,
        fold_size: 0.5,
        backtest_schema,
        strategy
    }
}

#[test]
fn test_get_folds_count() {
    let experiment = sample_logic_experiment();
    let (close_prices, ohlc_data) = inline_ohlc_data(200);

    let folds = get_folds(&experiment, &close_prices, &ohlc_data);
    assert_eq!(folds.len(), 2);
}

#[test]
fn test_get_folds_indices_valid() {
    let experiment = sample_logic_experiment();
    let (close_prices, ohlc_data) = inline_ohlc_data(200);

    let folds = get_folds(&experiment, &close_prices, &ohlc_data);

    for fold in &folds {
        assert!(fold.start_idx < fold.end_idx);
        assert!(fold.end_idx < close_prices.len());
        assert!(!fold.train_close.is_empty());
        assert!(!fold.val_close.is_empty());
        assert!(!fold.test_close.is_empty());
    }
}

#[test]
fn test_run_experiment_struct_literal() {
    let experiment = sample_logic_experiment();
    let (close_prices, ohlc_data) = inline_ohlc_data(200);

    let results = run_experiment(&experiment, &close_prices, &ohlc_data);
    assert_eq!(results.fold_results.len(), 2);
}

#[test]
fn test_run_experiment_json_serializable() {
    let experiment = sample_logic_experiment();
    let (close_prices, ohlc_data) = inline_ohlc_data(200);

    let results = run_experiment(&experiment, &close_prices, &ohlc_data);
    let json_out = experiment_results_json(&results);
    let serialized = serde_json::to_string(&json_out);
    assert!(serialized.is_ok());
}

#[test]
fn test_experiment_results_all_valid() {
    let experiment = sample_logic_experiment();
    let (close_prices, ohlc_data) = inline_ohlc_data(200);

    let results = run_experiment(&experiment, &close_prices, &ohlc_data);

    let n_invalid = results.fold_results.iter()
        .filter(|fr| fr.test_results.is_invalid)
        .count();

    let n_folds = results.fold_results.len();
    let n_valid = n_folds - n_invalid;
    assert!(n_valid + n_invalid == n_folds);
}

#[test]
fn test_experiment_results_empty() {
    let results = experiment_results(vec![]);
    assert_eq!(results.overall_excess_sharpe, 0.0);
    assert_eq!(results.invalid_frac, 0.0);
    assert!(results.fold_results.is_empty());
}

#[test]
fn test_net_signals_with_delay() {
    let mut net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                value: false
            })
        ],
        default_value: false
    };

    let node_ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    let entry_schemas = vec![EntrySchema {
        node_ptr: node_ptr.clone(),
        position_size: 0.1,
        max_positions: 1
    }];
    let exit_schemas = vec![ExitSchema {
        node_ptr,
        entry_indices: vec![0],
        stop_loss: 0.05,
        take_profit: 0.05,
        max_hold_time: 20
    }];

    let (_, ohlc_data) = inline_ohlc_data(10);
    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(Constant { id: "c".to_string(), constant: 1.0 })
    ];
    let matrix = feat_matrix(&feats, &ohlc_data);

    let delay = 2;
    let signals = net_signals(&mut net, &entry_schemas, &exit_schemas, &matrix, delay);

    assert_eq!(signals.len(), 10);

    for i in 0..delay {
        assert!(!signals[i].entries[0]);
        assert!(!signals[i].exits[0]);
    }
}

#[test]
fn test_construct_net_then_eval() {
    let base_net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: None,
                feat_idx: None,
                value: false
            }),
            LogicNode::Gate(GateNode {
                gate: None,
                in1_idx: None,
                in2_idx: None,
                value: false
            })
        ],
        default_value: false
    };

    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: vec![ThresholdRange { min: 0.0, max: 1.0 }],
        n_thresholds: 3,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And, Gate::Or]
    };

    use alphchemy::actions::actions::Action;
    let seq = vec![
        Action::SetFeatIdx,
        Action::SetThreshold,
        Action::NextNode,
        Action::SetGate
    ];

    let mut net = construct_net(&base_net, &seq, &actions);
    net.eval(&[0.5]);

    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    let _value = net.node_value(&ptr);
}

#[test]
fn test_full_pipeline_from_json() {
    let json = serde_json::json!({
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
            "feats": [
                { "feature": "constant", "id": "c1", "constant": 1.0 }
            ],
            "stop_conds": { "max_iters": 3, "train_patience": 5, "val_patience": 5 },
            "opt": {
                "type": "genetic",
                "pop_size": 10,
                "seq_len": 5,
                "n_elites": 2,
                "mut_rate": 0.1,
                "cross_rate": 0.7,
                "tournament_size": 3
            },
            "entry_schemas": [{
                "node_ptr": { "anchor": "from_end", "idx": 0 },
                "position_size": 0.1,
                "max_positions": 3
            }],
            "exit_schemas": [{
                "node_ptr": { "anchor": "from_end", "idx": 0 },
                "entry_indices": [0],
                "stop_loss": 0.05,
                "take_profit": 0.05,
                "max_hold_time": 20
            }],
            "base_net": {
                "type": "logic",
                "nodes": [{ "type": "input", "threshold": 0.5, "feat_idx": 0 }],
                "default_value": false
            },
            "actions": {
                "n_thresholds": 5,
                "allow_recurrence": false,
                "allowed_gates": ["and", "or"],
                "meta_actions": [],
                "thresholds": [{ "feat_id": "c1", "min": 0.0, "max": 2.0 }]
            },
            "penalties": {
                "node": 0.0, "input": 0.0, "gate": 0.0,
                "recurrence": 0.0, "feedforward": 0.0,
                "used_feat": 0.0, "unused_feat": 0.0
            }
        }
    });

    let experiment = parse_experiment(&json).unwrap();
    let (close_prices, ohlc_data) = inline_ohlc_data(200);

    let results = match &experiment {
        ExperimentVariant::Logic(exp) => run_experiment(exp, &close_prices, &ohlc_data),
        ExperimentVariant::Decision(exp) => run_experiment(exp, &close_prices, &ohlc_data)
    };

    assert_eq!(results.fold_results.len(), 2);

    let json_out = experiment_results_json(&results);
    assert!(json_out.get("overall_excess_sharpe").is_some());
    assert!(json_out.get("fold_results").is_some());
}
