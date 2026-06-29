use chrono::{DateTime, NaiveDateTime, NaiveDate, Utc, Duration};
use serde_json::{Value, json};

use crate::experiment::experiment::{Experiment, ExperimentVariant, run_experiment};
use crate::experiment::backtest::{BacktestSchema, BacktestMetric};
use crate::experiment::tojson::fold_results_json;
use super::parse::{Fields, Line, to_lines};
use super::parse_strategy::{parse_logic_strategy, parse_decision_strategy};

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
    let metric_texts = fields.string_list(&["metrics"])?;
    let metrics = parse_metrics(&metric_texts)?;
    let opt_text = fields.string(&["opt_metric"], "excess_sharpe");
    let opt_metric = parse_metric(&opt_text)?;

    if start_balance <= 0.0 {
        return Err("start_balance must be > 0.0".to_string());
    }
    if !metrics.contains(&opt_metric) {
        return Err("opt_metric must be in metrics".to_string());
    }

    let schema = BacktestSchema { start_offset, start_balance, delay, metrics, opt_metric };
    Ok(schema)
}

// === Experiment parsing ===

fn reject_empty_list_syntax(lines: &[Line]) -> Result<(), String> {
    for line in lines {
        let Some(parts) = line.text.split_once(':') else {
            continue;
        };
        let value = parts.1.trim();
        if value == "[]" {
            let key = parts.0.trim();
            return Err(format!("{key} must omit the key instead of using []"));
        }
    }
    Ok(())
}

pub fn parse_experiment(source: &str) -> Result<ExperimentVariant, String> {
    let lines = to_lines(source);
    reject_empty_list_syntax(&lines)?;
    let fields = Fields::from_lines(&lines);

    let val_size = fields.f64(&["val_size"], 0.2)?;
    let test_size = fields.f64(&["test_size"], 0.2)?;
    let cv_folds = fields.usize(&["cv_folds"], 5)?;
    let fold_size = fields.f64(&["fold_size"], 0.7)?;
    let start_timestamp = field_timestamp(&fields, &["start_timestamp"], default_start)?;
    let end_timestamp = field_timestamp(&fields, &["end_timestamp"], default_end)?;

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

    Ok(variant)
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
