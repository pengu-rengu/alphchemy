use chrono::{DateTime, NaiveDateTime, NaiveDate, Utc, Duration};

use alphchemy_engine::experiment::backtest::{BacktestSchema, BacktestMetric};
use alphchemy_engine::experiment::experiment::{Experiment, ExperimentVariant, TimeInterval};
use alphchemy_engine::optimizer::optimizer::Objective;
use super::parse::{Fields, to_lines};
use super::parse_strategy::{parse_logic_strategy, parse_decision_strategy};

const ISO_FORMAT: &str = "%Y-%m-%dT%H:%M:%S";
const DATETIME_FORMATS: [&str; 5] = [
    "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%b %d %Y %H:%M", "%Y-%m-%d %H:%M", "%b %d %Y"
];
const MAX_CV_FOLDS: usize = 10;

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
    match fields.option_string(keys)? {
        Some(text) => parse_timestamp(&text),
        None => Ok(default())
    }
}

fn parse_time_interval(text: &str) -> Result<TimeInterval, String> {
    match text {
        "1h" => Ok(TimeInterval::OneHour),
        _ => Err("time_interval must be 1h".to_string())
    }
}

// === Backtest schema parsing ===

pub fn parse_metric(text: &str) -> Result<BacktestMetric, String> {
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
    let mut metrics = Vec::with_capacity(texts.len());
    for text in texts {
        let metric = parse_metric(text)?;
        metrics.push(metric);
    }

    Ok(metrics)
}

fn parse_backtest_schema(fields: Option<Fields<'_>>) -> Result<BacktestSchema, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let start_offset = fields.usize(&["start_offset"], 50)?;
    let start_balance = fields.f64(&["start_balance"], 1000.0)?;
    let delay = fields.usize(&["delay"], 1)?;
    let metric_texts = fields.string_list(&["metrics"], vec!["excess_sharpe".to_string()])?;
    let metrics = parse_metrics(&metric_texts)?;

    if start_balance <= 0.0 {
        return Err("start_balance must be > 0.0".to_string());
    }

    Ok(BacktestSchema { start_offset, start_balance, delay, metrics })
}

fn parse_net_type(fields: Option<Fields<'_>>) -> Result<String, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    fields.string(&["type", "net_type", "network_type"], "logic")
}

// === Experiment parsing ===

fn validate_objectives(objectives: &[Objective], metrics: &[BacktestMetric]) -> Result<(), String> {
    for objective in objectives {
        if !metrics.contains(&objective.metric) {
            return Err("objective metric must be in metrics".to_string());
        }
    }
    Ok(())
}

pub fn parse_experiment(source: &str) -> Result<ExperimentVariant, String> {
    let lines = to_lines(source);
    let fields = Fields::from_lines(&lines)?;

    let val_size = fields.f64(&["val_size", "validation_size", "val_frac", "validation_fraction"], 0.2)?;
    let test_size = fields.f64(&["test_size", "test_frac", "test_fraction"], 0.2)?;
    let cv_folds = fields.usize(&["cv_folds", "cross_val_folds", "n_folds"], 5)?;
    let fold_size = fields.f64(&["fold_size", "fold_frac", "fold_fraction"], 0.8)?;
    let symbol = fields.string(&["symbol", "ticker"], "BTC_USDT")?;
    let interval_text = fields.string(&["time_interval", "interval"], "1h")?;
    let time_interval = parse_time_interval(&interval_text)?;
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
    if cv_folds > MAX_CV_FOLDS {
        return Err(format!("cv_folds must be <= {MAX_CV_FOLDS}"));
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

    let bt_fields = fields.child_fields(&["backtest_schema", "bt_schema", "backtest"])?;
    let backtest_schema = parse_backtest_schema(bt_fields)?;

    let strat_fields = fields.child_fields(&["strategy"])?;
    let net_fields = match strat_fields.as_ref() {
        Some(strat_fields) => {
            strat_fields.child_fields(&["base_net", "base_network", "initial_net", "initial_network"])?
        }
        None => None
    };
    let net_type = parse_net_type(net_fields)?;

    let variant = match net_type.as_str() {
        "logic" => {
            let strategy = parse_logic_strategy(strat_fields)?;
            validate_objectives(&strategy.opt.objectives, &backtest_schema.metrics)?;
            let experiment = Experiment {
                val_size, test_size, cv_folds, fold_size, symbol, time_interval, start_timestamp, end_timestamp, backtest_schema, strategy
            };
            ExperimentVariant::Logic(experiment)
        }
        "decision" => {
            let strategy = parse_decision_strategy(strat_fields)?;
            validate_objectives(&strategy.opt.objectives, &backtest_schema.metrics)?;
            let experiment = Experiment {
                val_size, test_size, cv_folds, fold_size, symbol, time_interval, start_timestamp, end_timestamp, backtest_schema, strategy
            };
            ExperimentVariant::Decision(experiment)
        }
        _ => return Err(format!("invalid network type: {net_type}"))
    };

    Ok(variant)
}
