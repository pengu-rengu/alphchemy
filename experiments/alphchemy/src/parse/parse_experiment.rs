use chrono::{DateTime, NaiveDateTime, NaiveDate, Utc, Duration};
use serde_json::{Value, json};

use crate::experiment::experiment::{Experiment, ExperimentVariant, run_experiment};
use crate::experiment::backtest::{BacktestSchema, BacktestMetric};
use crate::experiment::tojson::fold_results_json;
use super::parse::{Fields, to_lines};
use super::parse_strategy::{
    parse_logic_strategy, parse_decision_strategy, validate_logic_strategy, validate_decision_strategy
};

const ISO_FORMAT: &str = "%Y-%m-%dT%H:%M:%S";
const DATETIME_FORMATS: [&str; 5] = [
    "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%b %d %Y %H:%M", "%Y-%m-%d %H:%M", "%b %d %Y"
];

// === Timestamp parsing ===

fn parse_timestamp(text: &str) -> Result<String, String> {
    if let Ok(parsed) = DateTime::parse_from_rfc3339(text) {
        let naive = parsed.naive_utc();
        return Ok(naive.format(ISO_FORMAT).to_string());
    }

    for format in DATETIME_FORMATS {
        if let Ok(naive) = NaiveDateTime::parse_from_str(text, format) {
            return Ok(naive.format(ISO_FORMAT).to_string());
        }
    }

    if let Ok(date) = NaiveDate::parse_from_str(text, "%Y-%m-%d") {
        let naive = date.and_hms_opt(0, 0, 0).unwrap();
        return Ok(naive.format(ISO_FORMAT).to_string());
    }

    Err(format!("invalid timestamp: {text}"))
}

fn default_end() -> String {
    let now = Utc::now().naive_utc();
    now.format(ISO_FORMAT).to_string()
}

fn default_start() -> String {
    let span = Duration::days(180);
    let earlier = Utc::now() - span;
    let naive = earlier.naive_utc();
    naive.format(ISO_FORMAT).to_string()
}

fn field_timestamp(fields: &Fields, keys: &[&str], default: fn() -> String) -> Result<String, String> {
    match fields.option_string(keys) {
        Some(text) => parse_timestamp(&text),
        None => Ok(default())
    }
}

// === Backtest schema parsing ===

fn parse_metric(text: &str) -> Result<BacktestMetric, String> {
    match text {
        "sharpe" => Ok(BacktestMetric::Sharpe),
        "excess_sharpe" => Ok(BacktestMetric::ExcessSharpe),
        "max_drawdown" => Ok(BacktestMetric::MaxDrawdown),
        "mean_hold_time" => Ok(BacktestMetric::MeanHoldTime),
        "std_hold_time" => Ok(BacktestMetric::StdHoldTime),
        "total_entries" => Ok(BacktestMetric::TotalEntries),
        "total_exits" => Ok(BacktestMetric::TotalExits),
        "signal_exits" => Ok(BacktestMetric::SignalExits),
        "stop_loss_exits" => Ok(BacktestMetric::StopLossExits),
        "take_profit_exits" => Ok(BacktestMetric::TakeProfitExits),
        "max_hold_exits" => Ok(BacktestMetric::MaxHoldExits),
        _ => Err(format!("invalid metric: {text}"))
    }
}

fn parse_metrics(texts: &[String]) -> Result<Vec<BacktestMetric>, String> {
    if texts.is_empty() {
        return Ok(vec![BacktestMetric::ExcessSharpe]);
    }

    let mut metrics = Vec::with_capacity(texts.len());
    for text in texts {
        let metric = parse_metric(text)?;
        metrics.push(metric);
    }

    Ok(metrics)
}

fn parse_backtest_schema(fields: &Fields) -> Result<BacktestSchema, String> {
    let start_offset = fields.usize(&["start_offset"], 80)?;
    let start_balance = fields.f64(&["start_balance"], 10000.0)?;
    let delay = fields.usize(&["delay"], 1)?;
    let metric_texts = fields.string_list(&["metrics"]);
    let metrics = parse_metrics(&metric_texts)?;
    let opt_text = fields.string(&["opt_metric"], "excess_sharpe");
    let opt_metric = parse_metric(&opt_text)?;

    let schema = BacktestSchema { start_offset, start_balance, delay, metrics, opt_metric };
    Ok(schema)
}

// === Experiment parsing ===

pub fn parse_experiment(source: &str) -> Result<ExperimentVariant, String> {
    let lines = to_lines(source);
    let fields = Fields::from_lines(&lines);

    let val_size = fields.f64(&["val_size"], 0.2)?;
    let test_size = fields.f64(&["test_size"], 0.2)?;
    let cv_folds = fields.usize(&["cv_folds"], 5)?;
    let fold_size = fields.f64(&["fold_size"], 0.7)?;
    let start_timestamp = field_timestamp(&fields, &["start_timestamp"], default_start)?;
    let end_timestamp = field_timestamp(&fields, &["end_timestamp"], default_end)?;

    let bt_fields = fields.child_fields(&["backtest_schema", "bt_schema", "backtest"]);
    let backtest_schema = parse_backtest_schema(&bt_fields)?;

    let strat_fields = fields.child_fields(&["strategy"]);
    let net_fields = strat_fields.child_fields(&["base_net"]);
    let net_type = net_fields.string(&["type"], "logic");

    let variant = match net_type.as_str() {
        "logic" => {
            let strategy = parse_logic_strategy(&strat_fields)?;
            let experiment = Experiment {
                val_size, test_size, cv_folds, fold_size, start_timestamp, end_timestamp, backtest_schema, strategy
            };
            ExperimentVariant::Logic(experiment)
        }
        "decision" => {
            let strategy = parse_decision_strategy(&strat_fields)?;
            let experiment = Experiment {
                val_size, test_size, cv_folds, fold_size, start_timestamp, end_timestamp, backtest_schema, strategy
            };
            ExperimentVariant::Decision(experiment)
        }
        _ => return Err(format!("invalid network type: {net_type}"))
    };

    validate_experiment(&variant)?;
    Ok(variant)
}

// === Validation ===

fn validate_top(val_size: f64, test_size: f64, cv_folds: usize, fold_size: f64, start_timestamp: &str, end_timestamp: &str) -> Result<(), String> {
    if val_size <= 0.0 {
        return Err("val_size must be > 0.0".to_string());
    }
    if test_size <= 0.0 {
        return Err("test_size must be > 0.0".to_string());
    }

    let split_sum = val_size + test_size;
    if split_sum >= 1.0 {
        return Err("val_size + test_size must be < 1.0".to_string());
    }

    if cv_folds == 0 {
        return Err("cv_folds must be > 0".to_string());
    }
    if fold_size <= 0.0 {
        return Err("fold_size must be > 0.0 and <= 1.0".to_string());
    }
    if fold_size > 1.0 {
        return Err("fold_size must be > 0.0 and <= 1.0".to_string());
    }
    if start_timestamp >= end_timestamp {
        return Err("start_timestamp must be < end_timestamp".to_string());
    }

    Ok(())
}

fn validate_backtest_schema(schema: &BacktestSchema) -> Result<(), String> {
    if schema.start_balance <= 0.0 {
        return Err("start_balance must be > 0.0".to_string());
    }
    if schema.metrics.is_empty() {
        return Err("metrics must be non-empty".to_string());
    }
    if !schema.metrics.contains(&schema.opt_metric) {
        return Err("opt_metric must be in metrics".to_string());
    }
    Ok(())
}

pub fn validate_experiment(variant: &ExperimentVariant) -> Result<(), String> {
    match variant {
        ExperimentVariant::Logic(experiment) => {
            validate_top(experiment.val_size, experiment.test_size, experiment.cv_folds, experiment.fold_size, &experiment.start_timestamp, &experiment.end_timestamp)?;
            validate_backtest_schema(&experiment.backtest_schema)?;
            validate_logic_strategy(&experiment.strategy)?;
        }
        ExperimentVariant::Decision(experiment) => {
            validate_top(experiment.val_size, experiment.test_size, experiment.cv_folds, experiment.fold_size, &experiment.start_timestamp, &experiment.end_timestamp)?;
            validate_backtest_schema(&experiment.backtest_schema)?;
            validate_decision_strategy(&experiment.strategy)?;
        }
    }
    Ok(())
}

// === Run entry point ===

pub async fn run_variant(variant: &ExperimentVariant) -> Value {
    let run_result = match variant {
        ExperimentVariant::Logic(experiment) => run_experiment(experiment).await,
        ExperimentVariant::Decision(experiment) => run_experiment(experiment).await
    };

    match run_result {
        Ok(results) => fold_results_json(&results),
        Err(error) => json!({
            "error": error,
            "is_internal": false
        })
    }
}

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
