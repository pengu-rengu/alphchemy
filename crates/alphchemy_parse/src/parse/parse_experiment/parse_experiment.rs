use alphchemy_utils::parse_timestamp;
use chrono::{Utc, Duration};

use alphchemy_engine::experiment::backtest::BacktestMetric;
use alphchemy_engine::experiment::experiment::{Experiment, ExperimentVariant, TimeInterval};
use alphchemy_engine::optimizer::optimizer::Objective;
use super::super::parse::{Fields, to_lines};
use super::parse_strategy::{parse_logic_strategy, parse_decision_strategy};
use super::parse_backtest::parse_backtest_schema;

const ISO_FORMAT: &str = "%Y-%m-%dT%H:%M:%S";
const MAX_CV_FOLDS: usize = 10;

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

fn parse_net_type(fields: Option<Fields>) -> Result<String, String> {
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
