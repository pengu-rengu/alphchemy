use alphchemy_engine::experiment::backtest::{BacktestSchema, BacktestMetric};
use super::super::parse::Fields;

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

pub(super) fn parse_backtest_schema(fields: Option<Fields<'_>>) -> Result<BacktestSchema, String> {
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
