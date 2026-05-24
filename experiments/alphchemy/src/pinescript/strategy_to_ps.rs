use crate::experiment::backtest::BacktestSchema;
use crate::experiment::strategy::Strategy;
use crate::network::network::{Network, Penalties};
use crate::actions::actions::Actions;

use super::net_to_ps::NetToPs;

pub struct StrategyEmit {
    pub signal_lines: Vec<String>,
    pub action_lines: Vec<String>
}

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
        let qty = entry_schema.qty;
        let max_positions = entry_schema.max_positions;

        action_lines.push(format!("if active and entry_signal_{entry_id} and strategy.opentrades < {global_max_positions} and count_open_id(\"{entry_id}\") < {max_positions}"));
        action_lines.push(format!("    strategy.entry(\"{entry_id}\", strategy.long, qty={qty})"));

        for exit_schema in exit_schemas {
            let exit_id = &exit_schema.id;
            let applies = exit_schema.entry_ids.iter().any(|candidate| candidate == entry_id);
            if !applies {
                continue;
            }
            let tp_factor = 1.0 + exit_schema.take_profit;
            let sl_factor = 1.0 - exit_schema.stop_loss;
            action_lines.push(format!("    strategy.exit(\"{exit_id}_risk_{entry_id}\", from_entry=\"{entry_id}\", stop=close * {sl_factor}, limit=close * {tp_factor})"));
        }
    }

    for exit_schema in exit_schemas {
        let exit_id = &exit_schema.id;
        let max_hold = exit_schema.max_hold_time;

        for entry_id in &exit_schema.entry_ids {
            action_lines.push(format!("if active and (exit_signal_{exit_id} or any_open_hold_exceeded(\"{entry_id}\", {max_hold}))"));
            action_lines.push(format!("    strategy.close(\"{entry_id}\", comment=\"{exit_id}\")"));
        }
    }

    Ok(StrategyEmit {
        signal_lines,
        action_lines
    })
}
