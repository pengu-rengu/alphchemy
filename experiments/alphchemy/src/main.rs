use std::collections::HashMap;
use ndarray::Array1;
use rand::Rng;

use alphchemy::network::network::Anchor;
use alphchemy::experiment::experiment::run_experiment;
use alphchemy::experiment::experiment::{parse_experiment, ExperimentVariant};
use alphchemy::experiment::tojson::{experiment_results_json, backtest_results_json};
use alphchemy::experiment::strategy::{NetSignals, EntrySchema, ExitSchema};
use alphchemy::experiment::backtest::{BacktestSchema, backtest};
use alphchemy::network::network::NodePtr;

fn demo_backtest() -> Result<(), Box<dyn std::error::Error>> {
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
    println!("Demo backtest results:");
    println!("{}", serde_json::to_string_pretty(&json_out)?);
    Ok(())
}

fn generate_ohlc_data(n_bars: usize) -> (Vec<f64>, HashMap<String, Array1<f64>>) {
    let mut rng = rand::rng();
    let mut close = Vec::with_capacity(n_bars);
    let mut price = 100.0;

    for _ in 0..n_bars {
        price *= 1.0 + rng.random_range(-0.02..0.02);
        close.push(price);
    }

    let mut open = Vec::with_capacity(n_bars);
    let mut high = Vec::with_capacity(n_bars);
    let mut low = Vec::with_capacity(n_bars);

    for i in 0..n_bars {
        let c = close[i];
        let spread = c * 0.01;
        open.push(c + rng.random_range(-spread..spread));
        high.push(c + rng.random_range(0.0..spread * 2.0));
        low.push(c - rng.random_range(0.0..spread * 2.0));
    }

    let mut ohlc_data = HashMap::new();
    ohlc_data.insert("open".to_string(), Array1::from_vec(open));
    ohlc_data.insert("high".to_string(), Array1::from_vec(high));
    ohlc_data.insert("low".to_string(), Array1::from_vec(low));
    ohlc_data.insert("close".to_string(), Array1::from_vec(close.clone()));

    (close, ohlc_data)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    demo_backtest()?;

    let json_str = std::fs::read_to_string("data/experiment.json")?;
    let json: serde_json::Value = serde_json::from_str(&json_str)?;

    let experiment = parse_experiment(&json).map_err(|e| -> Box<dyn std::error::Error> { e.into() })?;

    let (close_prices, ohlc_data) = generate_ohlc_data(500);

    println!("Running experiment...");

    let results = match &experiment {
        ExperimentVariant::Logic(exp) => run_experiment(exp, &close_prices, &ohlc_data),
        ExperimentVariant::Decision(exp) => run_experiment(exp, &close_prices, &ohlc_data)
    };

    let json_out = experiment_results_json(&results);
    println!("{}", serde_json::to_string_pretty(&json_out)?);

    Ok(())
}
