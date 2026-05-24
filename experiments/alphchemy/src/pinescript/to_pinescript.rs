use chrono::{DateTime, Utc};

use crate::actions::actions::{Action, Actions, construct_net};
use crate::experiment::experiment::{Experiment, ExperimentVariant};
use crate::network::network::{Network, Penalties};

use super::net_to_ps::NetToPs;
use super::features_to_ps::emit_feats;
use super::strategy_to_ps::emit_strategy;

pub const CUSTOM_HELPERS: &str = r#"custom_sma(source, window) =>
    var float sum = 0.0
    sum += source
    if bar_index >= window
        sum -= source[window]
    if bar_index + 1 < window
        0.0
    else
        sum / window

custom_ema(source, window, smooth) =>
    alpha = smooth / (window + 1.0)
    var float prev = 0.0
    var float seed = 0.0
    if bar_index < window
        seed += source
    else if bar_index == window
        prev := alpha * source + (1.0 - alpha) * (seed / window)
    else
        prev := alpha * source + (1.0 - alpha) * prev
    prev

custom_stdev(source, window) =>
    mean_val = custom_sma(source, window)
    if bar_index + 1 < window
        0.0
    else
        variance = 0.0
        for offset = 0 to window - 1
            diff = nz(source[offset]) - mean_val
            variance += math.pow(diff, 2)
        math.sqrt(variance / window)

custom_highest(source, window) =>
    if bar_index + 1 < window
        0.0
    else
        max_val = nz(source[window - 1])
        for offset = 0 to window - 1
            value = nz(source[offset])
            if value > max_val
                max_val := value
        max_val

custom_lowest(source, window) =>
    if bar_index + 1 < window
        0.0
    else
        min_val = nz(source[window - 1])
        for offset = 0 to window - 1
            value = nz(source[offset])
            if value < min_val
                min_val := value
        min_val

count_open_id(target_id) =>
    count = 0
    if strategy.opentrades > 0
        for trade_i = 0 to strategy.opentrades - 1
            if strategy.opentrades.entry_id(trade_i) == target_id
                count += 1
    count

any_open_hold_exceeded(target_id, max_hold) =>
    hit = false
    if strategy.opentrades > 0
        for trade_i = 0 to strategy.opentrades - 1
            if strategy.opentrades.entry_id(trade_i) == target_id
                if bar_index - strategy.opentrades.entry_bar_index(trade_i) >= max_hold
                    hit := true
    hit"#;

#[derive(Clone, Copy, Debug)]
pub struct FoldPeriods {
    pub train_start_timestamp: f64,
    pub train_end_timestamp: f64,
    pub val_start_timestamp: f64,
    pub val_end_timestamp: f64,
    pub test_start_timestamp: f64,
    pub test_end_timestamp: f64
}

fn format_timestamp(timestamp: f64) -> Result<String, String> {
    let maybe_datetime = DateTime::<Utc>::from_timestamp(timestamp as i64, 0);
    let datetime = maybe_datetime.ok_or_else(|| format!("invalid timestamp: {timestamp}"))?;
    Ok(datetime.format("%Y-%m-%dT%H:%M:%SZ").to_string())
}

fn header(title: &str, start_balance: f64, pyramiding: usize, fold_periods: &FoldPeriods) -> Result<Vec<String>, String> {
    let train_start = format_timestamp(fold_periods.train_start_timestamp)?;
    let train_end = format_timestamp(fold_periods.train_end_timestamp)?;
    let val_start = format_timestamp(fold_periods.val_start_timestamp)?;
    let val_end = format_timestamp(fold_periods.val_end_timestamp)?;
    let test_start = format_timestamp(fold_periods.test_start_timestamp)?;
    let test_end = format_timestamp(fold_periods.test_end_timestamp)?;

    Ok(vec![
        "//@version=6".to_string(),
        "// Auto-generated from alphchemy experiment.".to_string(),
        "// Note: TradingView applies stop loss/take profit intra-bar; experiment backtest uses bar close.".to_string(),
        format!("// Training period: {train_start} to {train_end}"),
        format!("// Validation period: {val_start} to {val_end}"),
        format!("// Out-of-sample test period: {test_start} to {test_end}"),
        format!("strategy(\"{title}\", overlay=true, initial_capital={start_balance}, pyramiding={pyramiding})")
    ])
}

fn build_pinescript<T, P, A>(experiment: &Experiment<T, P, A>, title: &str, best_val_seq: &[Action], fold_periods: &FoldPeriods) -> Result<String, String>
where
    T: Network + Clone + NetToPs,
    P: Penalties<T>,
    A: Actions<T>
{
    let strategy = &experiment.strategy;
    let schema = &experiment.backtest_schema;
    let net = construct_net(&strategy.base_net, best_val_seq, &strategy.actions);
    let net_emit = net.emit(schema.delay)?;
    let feat_lines = emit_feats(&strategy.feats)?;
    let strategy_emit = emit_strategy(strategy, schema, &net)?;
    let pyramiding = strategy.global_max_positions;

    let mut sections: Vec<String> = Vec::new();
    sections.push(header(title, schema.start_balance, pyramiding, fold_periods)?.join("\n"));
    sections.push(format!("// === Helpers ===\n{}", CUSTOM_HELPERS));
    sections.push(format!("// === Features ===\n{}", feat_lines.join("\n")));
    sections.push(format!("// === Net declarations ===\n{}", net_emit.declarations.join("\n")));
    sections.push(format!("// === Net evaluation (per bar) ===\n{}", net_emit.per_bar.join("\n")));
    sections.push(format!("// === Signals ===\n{}", strategy_emit.signal_lines.join("\n")));
    sections.push(format!("// === Actions ===\n{}", strategy_emit.action_lines.join("\n")));

    Ok(sections.join("\n\n") + "\n")
}

pub fn experiment_to_pinescript(experiment: &ExperimentVariant, title: &str, best_val_seq: &[Action], fold_periods: &FoldPeriods) -> Result<String, String> {
    match experiment {
        ExperimentVariant::Logic(exp) => build_pinescript(exp, title, best_val_seq, fold_periods),
        ExperimentVariant::Decision(exp) => build_pinescript(exp, title, best_val_seq, fold_periods)
    }
}
