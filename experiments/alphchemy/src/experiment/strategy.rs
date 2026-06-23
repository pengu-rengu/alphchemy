use serde_json::Value;

use crate::network::network::{Network, NodePtr, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties, parse_logic_net, parse_logic_penalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties, parse_decision_net, parse_decision_penalties};
use crate::features::features::{Feature, TimestampedTable};
use crate::features::features::{feat_ids, parse_feats};
use crate::actions::actions::Actions;
use crate::actions::logic_actions::{LogicActions, parse_logic_actions};
use crate::actions::decision_actions::{DecisionActions, parse_decision_actions};
use crate::optimizer::optimizer::StopConds;
use crate::optimizer::optimizer::parse_stop_conds;
use crate::optimizer::genetic::GeneticOpt;
use crate::optimizer::genetic::parse_opt;
use crate::utils::{parse_json, get_field, field_array, field_f64, field_usize};

#[derive(Clone, Debug)]
pub struct NetSignals {
    pub entry: bool,
    pub exit: bool
}

pub struct Strategy<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub base_net: T,
    pub feats: Vec<Box<dyn Feature>>,
    pub actions: A,
    pub penalties: P,
    pub stop_conds: StopConds,
    pub opt: GeneticOpt,
    pub entry_ptr: NodePtr,
    pub exit_ptr: NodePtr,
    pub stop_loss: f64,
    pub take_profit: f64,
    pub max_hold_time: usize,
    pub qty: f64
}

pub fn net_signals<T: Network>(net: &mut T, entry_ptr: &NodePtr, exit_ptr: &NodePtr, feat_table: &TimestampedTable, start_idx: usize, end_idx: usize, delay: usize) -> Vec<NetSignals> {
    let n_rows = end_idx - start_idx + 1;
    let mut signals = Vec::with_capacity(n_rows);

    for _ in 0..delay {
        signals.push( NetSignals {
            entry: false,
            exit: false
        });
    }

    net.reset_state();

    for i in delay..n_rows {
        let row_idx = start_idx + i - delay;
        net.eval(feat_table, row_idx);

        let entry = net.node_value(entry_ptr);
        let exit = net.node_value(exit_ptr);
        let new_signals = NetSignals {
            entry,
            exit
        };
        signals.push(new_signals);
    }

    signals
}

struct StrategyJson<'a> {
    base_net_json: &'a Value,
    feats_json: &'a Vec<Value>,
    actions_json: &'a Value,
    penalties_json: &'a Value,
    stop_conds_json: &'a Value,
    opt_json: &'a Value
}

struct StrategyData {
    feats: Vec<Box<dyn Feature>>,
    feat_ids: Vec<String>,
    stop_conds: StopConds,
    opt: GeneticOpt,
    entry_ptr: NodePtr,
    exit_ptr: NodePtr,
    stop_loss: f64,
    take_profit: f64,
    max_hold_time: usize,
    qty: f64
}

fn parse_strategy_json<'a>(json: &'a Value) -> Result<StrategyJson<'a>, String> {
    let base_net_json = get_field(json, "base_net")?;
    let feats_json = field_array(json, "feats")?;
    let actions_json = get_field(json, "actions")?;
    let penalties_json = get_field(json, "penalties")?;
    let stop_conds_json = get_field(json, "stop_conds")?;
    let opt_json = get_field(json, "opt")?;

    Ok(StrategyJson {
        base_net_json,
        feats_json,
        actions_json,
        penalties_json,
        stop_conds_json,
        opt_json
    })
}

fn parse_strategy_data(json: &Value, strategy_json: &StrategyJson) -> Result<StrategyData, String> {
    let feats = parse_feats(strategy_json.feats_json)?;
    let feat_ids = feat_ids(&feats);
    let stop_conds = parse_stop_conds(strategy_json.stop_conds_json)?;
    let opt = parse_opt(strategy_json.opt_json)?;

    let entry_ptr_json = get_field(json, "entry_ptr")?;
    let exit_ptr_json = get_field(json, "exit_ptr")?;
    let entry_ptr = parse_json::<NodePtr>(entry_ptr_json)?;
    let exit_ptr: NodePtr = parse_json::<NodePtr>(exit_ptr_json)?;

    let stop_loss = field_f64(json, "stop_loss")?;
    let take_profit = field_f64(json, "take_profit")?;
    let max_hold_time = field_usize(json, "max_hold_time")?;
    let qty = field_f64(json, "qty")?;

    if stop_loss <= 0.0 { return Err("stop_loss must be > 0.0".to_string()); }
    if take_profit <= 0.0 { return Err("take_profit must be > 0.0".to_string()); }
    if max_hold_time == 0 { return Err("max_hold_time must be > 0".to_string()); }
    if qty <= 0.0 { return Err("qty must be > 0.0".to_string()); }

    Ok(StrategyData {
        feats,
        feat_ids,
        stop_conds,
        opt,
        entry_ptr,
        exit_ptr,
        stop_loss,
        take_profit,
        max_hold_time,
        qty
    })
}

pub fn parse_logic_strategy(json: &Value) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let strategy_json = parse_strategy_json(json)?;
    let strategy_data = parse_strategy_data(json, &strategy_json)?;

    let base_net = parse_logic_net(strategy_json.base_net_json, &strategy_data.feat_ids)?;
    let actions = parse_logic_actions(strategy_json.actions_json, &strategy_data.feats)?;
    let penalties = parse_logic_penalties(strategy_json.penalties_json)?;

    Ok(Strategy {
        base_net,
        feats: strategy_data.feats,
        actions,
        penalties,
        stop_conds: strategy_data.stop_conds,
        opt: strategy_data.opt,
        entry_ptr: strategy_data.entry_ptr,
        exit_ptr: strategy_data.exit_ptr,
        stop_loss: strategy_data.stop_loss,
        take_profit: strategy_data.take_profit,
        max_hold_time: strategy_data.max_hold_time,
        qty: strategy_data.qty
    })
}

pub fn parse_decision_strategy(json: &Value) -> Result<Strategy<DecisionNet, DecisionPenalties, DecisionActions>, String> {
    let strategy_json = parse_strategy_json(json)?;
    let strategy_data = parse_strategy_data(json, &strategy_json)?;

    let base_net = parse_decision_net(strategy_json.base_net_json, &strategy_data.feat_ids)?;
    let actions = parse_decision_actions(strategy_json.actions_json, &strategy_data.feats)?;
    let penalties = parse_decision_penalties(strategy_json.penalties_json)?;

    Ok(Strategy {
        base_net,
        feats: strategy_data.feats,
        actions,
        penalties,
        stop_conds: strategy_data.stop_conds,
        opt: strategy_data.opt,
        entry_ptr: strategy_data.entry_ptr,
        exit_ptr: strategy_data.exit_ptr,
        stop_loss: strategy_data.stop_loss,
        take_profit: strategy_data.take_profit,
        max_hold_time: strategy_data.max_hold_time,
        qty: strategy_data.qty
    })
}
