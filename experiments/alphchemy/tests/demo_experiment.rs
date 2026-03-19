use rand::Rng;

use alphchemy::experiment::experiment::{parse_experiment, run_experiment, ExperimentVariant};
use alphchemy::experiment::tojson::{experiment_results_json, backtest_results_json};
use alphchemy::experiment::strategy::{NetSignals, EntrySchema, ExitSchema};
use alphchemy::experiment::backtest::{BacktestSchema, backtest};
use alphchemy::network::network::{Anchor, NodePtr};
use alphchemy::test_utils::generate_ohlc_data;

#[test]
fn test_full_experiment_pipeline() {
    let json_str = std::fs::read_to_string("data/experiment.json")
        .expect("test requires data/experiment.json");
    let json: serde_json::Value = serde_json::from_str(&json_str)
        .expect("test JSON must be valid");

    let experiment = parse_experiment(&json).unwrap();
    let (close_prices, ohlc_data) = generate_ohlc_data(500);

    let results = match &experiment {
        ExperimentVariant::Logic(exp) => run_experiment(exp, &close_prices, &ohlc_data),
        ExperimentVariant::Decision(exp) => run_experiment(exp, &close_prices, &ohlc_data)
    };

    let json_out = experiment_results_json(&results);
    let serialized = serde_json::to_string_pretty(&json_out);
    assert!(serialized.is_ok());
}

#[test]
fn test_demo_backtest() {
    let n_bars = 200;
    let mut rng = rand::rng();
    let mut close_prices = Vec::with_capacity(n_bars);
    let mut price = 100.0;
    for _ in 0..n_bars {
        price *= 1.0 + rng.random_range(-0.02..0.02);
        close_prices.push(price);
    }

    let entry_schema = EntrySchema {
        node_ptr: NodePtr { anchor: Anchor::FromEnd, idx: 0 },
        position_size: 0.1,
        max_positions: 3
    };

    let exit_schema = ExitSchema {
        node_ptr: NodePtr { anchor: Anchor::FromEnd, idx: 0 },
        entry_indices: vec![0],
        stop_loss: 0.05,
        take_profit: 0.05,
        max_hold_time: 20
    };

    let backtest_schema = BacktestSchema {
        start_offset: 10,
        start_balance: 10000.0,
        delay: 1
    };

    let mut signals = Vec::with_capacity(n_bars);
    for i in 0..n_bars {
        signals.push(NetSignals {
            entries: vec![i % 10 == 0],
            exits: vec![i % 15 == 0]
        });
    }

    let results = backtest(
        signals,
        &[entry_schema],
        &[exit_schema],
        &backtest_schema,
        &close_prices
    );

    let json_out = backtest_results_json(&results);
    let serialized = serde_json::to_string_pretty(&json_out);
    assert!(serialized.is_ok());
}

#[test]
fn test_backtest_start_offset_exceeds_data() {
    let close_prices = vec![100.0, 101.0, 102.0];

    let entry_schema = EntrySchema {
        node_ptr: NodePtr { anchor: Anchor::FromEnd, idx: 0 },
        position_size: 0.1,
        max_positions: 1
    };

    let exit_schema = ExitSchema {
        node_ptr: NodePtr { anchor: Anchor::FromEnd, idx: 0 },
        entry_indices: vec![0],
        stop_loss: 0.05,
        take_profit: 0.05,
        max_hold_time: 10
    };

    let backtest_schema = BacktestSchema {
        start_offset: 100,
        start_balance: 10000.0,
        delay: 1
    };

    let signals = vec![
        NetSignals { entries: vec![false], exits: vec![false] },
        NetSignals { entries: vec![false], exits: vec![false] },
        NetSignals { entries: vec![false], exits: vec![false] }
    ];

    let results = backtest(signals, &[entry_schema], &[exit_schema], &backtest_schema, &close_prices);
    assert!(results.is_invalid);
}

#[test]
fn test_invalid_json_parse() {
    let bad_json: serde_json::Value = serde_json::json!({});
    let result = parse_experiment(&bad_json);
    assert!(result.is_err());
}

#[test]
fn test_empty_fold_results() {
    let results = alphchemy::experiment::experiment::experiment_results(vec![]);
    assert_eq!(results.overall_excess_sharpe, 0.0);
    assert_eq!(results.invalid_frac, 0.0);
}
