use crate::experiment::backtest::BacktestSchema;
use crate::experiment::strategy::Strategy;
use crate::network::network::{Network, Penalties};
use crate::actions::actions::Actions;

use super::net_to_ps::NetToPs;

pub struct StrategyEmit {
    pub helpers: Vec<String>,
    pub signal_lines: Vec<String>,
    pub action_lines: Vec<String>
}

fn quote(value: &str) -> String {
    let escaped = value.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"")
}

const COUNT_OPEN_HELPER: &str = r#"count_open_id(target_id) =>
    count = 0
    if strategy.opentrades > 0
        for trade_i = 0 to strategy.opentrades - 1
            if strategy.opentrades.entry_id(trade_i) == target_id
                count += 1
    count"#;

const MAX_HOLD_HELPER: &str = r#"any_open_hold_exceeded(target_id, max_hold) =>
    hit = false
    if strategy.opentrades > 0
        for trade_i = 0 to strategy.opentrades - 1
            if strategy.opentrades.entry_id(trade_i) == target_id
                if bar_index - strategy.opentrades.entry_bar_index(trade_i) >= max_hold
                    hit := true
    hit"#;

pub fn emit_strategy<T, P, A>(
    strategy: &Strategy<T, P, A>,
    schema: &BacktestSchema,
    net: &T
) -> Result<StrategyEmit, String>
where
    T: Network + NetToPs,
    P: Penalties<T>,
    A: Actions<T>
{
    let entry_schemas = &strategy.entry_schemas;
    let exit_schemas = &strategy.exit_schemas;
    let global_max_positions = strategy.global_max_positions;

    let helpers = vec![
        COUNT_OPEN_HELPER.to_string(),
        MAX_HOLD_HELPER.to_string()
    ];

    let mut signal_lines = Vec::new();
    for entry_schema in entry_schemas {
        let expr = net.node_value_expr(&entry_schema.node_ptr);
        signal_lines.push(format!("entry_signal_{} = {expr}", entry_schema.id));
    }
    for exit_schema in exit_schemas {
        let expr = net.node_value_expr(&exit_schema.node_ptr);
        signal_lines.push(format!("exit_signal_{} = {expr}", exit_schema.id));
    }

    let mut action_lines = Vec::new();
    let start_offset = schema.start_offset;
    action_lines.push(format!("active = bar_index >= {start_offset}"));

    for entry_schema in entry_schemas {
        let entry_id = &entry_schema.id;
        let entry_quoted = quote(entry_id);
        let qty = entry_schema.qty;
        let max_positions = entry_schema.max_positions;

        action_lines.push(format!("if active and entry_signal_{entry_id} and strategy.opentrades < {global_max_positions} and count_open_id({entry_quoted}) < {max_positions}"));
        action_lines.push(format!("    strategy.entry({entry_quoted}, strategy.long, qty={qty})"));

        for exit_schema in exit_schemas {
            let exit_id = &exit_schema.id;
            let applies = exit_schema.entry_ids.iter().any(|candidate| candidate == entry_id);
            if !applies {
                continue;
            }
            let tp_factor = 1.0 + exit_schema.take_profit;
            let sl_factor = 1.0 - exit_schema.stop_loss;
            let risk_tag = quote(&format!("{exit_id}_risk_{entry_id}"));
            action_lines.push(format!("    strategy.exit({risk_tag}, from_entry={entry_quoted}, stop=close * {sl_factor}, limit=close * {tp_factor})"));
        }
    }

    for exit_schema in exit_schemas {
        let exit_id = &exit_schema.id;
        let max_hold = exit_schema.max_hold_time;

        for entry_id in &exit_schema.entry_ids {
            let entry_quoted = quote(entry_id);
            action_lines.push(format!("if active and (exit_signal_{exit_id} or any_open_hold_exceeded({entry_quoted}, {max_hold}))"));
            action_lines.push(format!("    strategy.close({entry_quoted}, comment={})", quote(exit_id)));
        }
    }

    Ok(StrategyEmit {
        helpers,
        signal_lines,
        action_lines
    })
}
