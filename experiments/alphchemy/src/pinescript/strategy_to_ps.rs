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
    action_lines.push(format!("take_profit_hit = strategy.position_size > 0 and close > strategy.position_avg_price * {tp_factor}"));
    action_lines.push(format!("stop_loss_hit = strategy.position_size > 0 and close < strategy.position_avg_price * {sl_factor}"));
    action_lines.push(format!("max_hold_hit = any_open_hold_exceeded(\"entry\", {max_hold})"));
    action_lines.push("risk_exit = take_profit_hit or stop_loss_hit or max_hold_hit".to_string());

    action_lines.push("if entry_signal and strategy.opentrades == 0".to_string());
    action_lines.push(format!("    strategy.entry(\"entry\", strategy.long, qty={qty})"));

    action_lines.push("if risk_exit".to_string());
    action_lines.push("    strategy.close(\"entry\", comment=\"risk_exit\")".to_string());
    action_lines.push("else if strategy.position_size > 0 and exit_signal".to_string());
    action_lines.push("    strategy.close(\"entry\", comment=\"signal_exit\")".to_string());

    Ok(StrategyEmit {
        signal_lines,
        action_lines
    })
}
