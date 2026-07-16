pub mod strategy;
pub mod backtest;
pub mod experiment;
pub mod tojson;

use serde_json::{Value, json};

use self::experiment::ExperimentVariant;
use self::tojson::fold_results_json;

pub async fn run_variant(variant: &ExperimentVariant) -> Value {
    let run_result = match variant {
        ExperimentVariant::Logic(experiment) => experiment.run().await,
        ExperimentVariant::Decision(experiment) => experiment.run().await
    };

    match run_result {
        Ok(results) => fold_results_json(&results),
        Err(error) => json!({
            "error": error,
            "is_internal": false
        })
    }
}
