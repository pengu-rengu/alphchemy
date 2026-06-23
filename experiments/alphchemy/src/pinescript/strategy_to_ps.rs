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
    let entry_expr = net.node_value_expr(&strategy.entry_ptr);
    let exit_expr = net.node_value_expr(&strategy.exit_ptr);

    let mut signal_lines = Vec::new();
    signal_lines.push(format!("entry_signal = {entry_expr}"));
    signal_lines.push(format!("exit_signal = {exit_expr}"));

    let qty = strategy.qty;
    let tp_factor = 1.0 + strategy.take_profit;
    let sl_factor = 1.0 - strategy.stop_loss;
    let max_hold = strategy.max_hold_time;

    let mut action_lines = Vec::new();
    let start_offset = schema.start_offset;
    action_lines.push(format!("active = bar_index >= {start_offset}"));

    action_lines.push("if active and entry_signal and strategy.opentrades == 0".to_string());
    action_lines.push(format!("    strategy.entry(\"entry\", strategy.long, qty={qty})"));
    action_lines.push(format!("    strategy.exit(\"exit_risk\", from_entry=\"entry\", stop=close * {sl_factor}, limit=close * {tp_factor})"));

    action_lines.push(format!("if active and (exit_signal or any_open_hold_exceeded(\"entry\", {max_hold}))"));
    action_lines.push("    strategy.close(\"entry\", comment=\"exit\")".to_string());

    Ok(StrategyEmit {
        signal_lines,
        action_lines
    })
}
