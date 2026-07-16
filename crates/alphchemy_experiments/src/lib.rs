pub mod process_experiment;

use alphchemy_engine::experiment::run_variant;
use alphchemy_parse::parse::parse_experiment::parse_experiment;
use serde_json::{Value, json};

pub async fn run_experiment_source(source: &str) -> Value {
    match parse_experiment(source) {
        Ok(variant) => run_variant(&variant).await,
        Err(error) => {
            println!("{error}");
            json!({
                "error": error,
                "is_internal": false
            })
        }
    }
}
