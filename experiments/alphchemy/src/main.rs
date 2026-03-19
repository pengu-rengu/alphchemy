mod network;
mod features;
mod actions;
mod optimizer;
mod experiment;
mod utils;


use std::collections::HashMap;
use ndarray::Array1;
use rand::Rng;

use experiment::experiment::run_experiment;
use experiment::experiment::{parse_experiment, ExperimentVariant};
use experiment::tojson::experiment_results_json;

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

fn main() {
    
    let json_str = std::fs::read_to_string("data/experiment.json")
        .expect("failed to read data/experiment.json");
    let json: serde_json::Value = serde_json::from_str(&json_str)
        .expect("invalid JSON");

    let experiment = parse_experiment(&json)
        .expect("failed to parse experiment");

    let (close_prices, ohlc_data) = generate_ohlc_data(500);

    println!("Running experiment...");

    let results = match &experiment {
        ExperimentVariant::Logic(exp) => run_experiment(exp, &close_prices, &ohlc_data),
        ExperimentVariant::Decision(exp) => run_experiment(exp, &close_prices, &ohlc_data)
    };

    let json_out = experiment_results_json(&results);
    println!("{}", serde_json::to_string_pretty(&json_out).unwrap());
    
}
