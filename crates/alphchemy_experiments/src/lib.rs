pub mod fetch_data;
pub mod process_experiment;

use alphchemy_engine::experiment::run_variant;
use alphchemy_parse::parse::parse_experiment::parse_experiment;
use serde_json::{Value, json};

use self::fetch_data::fetch_experiment_data;

pub async fn run_experiment_source(source: &str) -> Value {
    match parse_experiment(source) {
        Ok(variant) => {
            let data_result = fetch_experiment_data(&variant);
            match data_result {
                Ok(data) => run_variant(&variant, &data).await,
                Err(error) => json!({
                    "error": error,
                    "is_internal": false
                })
            }
        }
        Err(error) => {
            println!("{error}");
            json!({
                "error": error,
                "is_internal": false
            })
        }
    }
}
