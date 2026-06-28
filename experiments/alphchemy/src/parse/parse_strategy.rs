use crate::experiment::strategy::Strategy;
use crate::features::features::{Feature, feat_ids};
use crate::network::network::{NodePtr, Anchor, Network, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties};
use crate::actions::actions::Actions;
use crate::actions::logic_actions::LogicActions;
use crate::actions::decision_actions::DecisionActions;
use crate::optimizer::optimizer::StopConds;
use crate::optimizer::genetic::GeneticOpt;
use super::parse::Fields;
use super::parse_features::parse_feats;
use super::parse_net::{
    parse_logic_net, parse_decision_net, parse_logic_penalties, parse_decision_penalties,
    validate_logic_net, validate_decision_net, validate_logic_penalties, validate_decision_penalties
};
use super::parse_actions::{
    parse_logic_actions, parse_decision_actions, validate_logic_actions, validate_decision_actions
};
use super::parse_optimizer::{parse_stop_conds, parse_opt, validate_stop_conds, validate_opt};

// === Node pointer parsing ===

fn parse_anchor(text: &str) -> Result<Anchor, String> {
    match text {
        "from_start" => Ok(Anchor::FromStart),
        "from_end" => Ok(Anchor::FromEnd),
        _ => Err(format!("invalid anchor: {text}"))
    }
}

fn parse_node_ptr(fields: &Fields<'_>) -> Result<NodePtr, String> {
    let anchor_text = fields.string(&["anchor"], "from_start");
    let anchor = parse_anchor(&anchor_text)?;
    let idx = fields.usize(&["idx"], 0)?;

    let node_ptr = NodePtr { anchor, idx };
    Ok(node_ptr)
}

// === Shared strategy parsing ===

struct StrategyShared {
    feats: Vec<Box<dyn Feature>>,
    stop_conds: StopConds,
    opt: GeneticOpt,
    entry_ptr: NodePtr,
    exit_ptr: NodePtr,
    stop_loss: f64,
    take_profit: f64,
    max_hold_time: usize,
    qty: f64
}

fn parse_strategy_shared(fields: &Fields) -> Result<StrategyShared, String> {
    let feat_fields = fields.child_fields(&["feats"]);
    let feats = parse_feats(&feat_fields)?;

    let stop_fields = fields.child_fields(&["stop_conds"]);
    let stop_conds = parse_stop_conds(&stop_fields)?;

    let opt_fields = fields.child_fields(&["opt"]);
    let opt = parse_opt(&opt_fields)?;

    let entry_fields = fields.child_fields(&["entry_ptr"]);
    let entry_ptr = parse_node_ptr(&entry_fields)?;
    let exit_fields = fields.child_fields(&["exit_ptr"]);
    let exit_ptr = parse_node_ptr(&exit_fields)?;

    let stop_loss = fields.f64(&["stop_loss"], 0.04)?;
    let take_profit = fields.f64(&["take_profit"], 0.08)?;
    let max_hold_time = fields.usize(&["max_hold_time"], 72)?;
    let qty = fields.f64(&["qty"], 0.01)?;

    let shared = StrategyShared {
        feats, stop_conds, opt, entry_ptr, exit_ptr, stop_loss, take_profit, max_hold_time, qty
    };
    Ok(shared)
}

// === Strategy parsing ===

pub fn parse_logic_strategy(fields: &Fields) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let shared = parse_strategy_shared(fields)?;

    let net_fields = fields.child_fields(&["base_net"]);
    let base_net = parse_logic_net(&net_fields)?;

    let actions_fields = fields.child_fields(&["actions"]);
    let actions = parse_logic_actions(&actions_fields)?;

    let pen_fields = fields.child_fields(&["penalties"]);
    let penalties = parse_logic_penalties(&pen_fields)?;

    let strategy = Strategy {
        base_net,
        feats: shared.feats,
        actions,
        penalties,
        stop_conds: shared.stop_conds,
        opt: shared.opt,
        entry_ptr: shared.entry_ptr,
        exit_ptr: shared.exit_ptr,
        stop_loss: shared.stop_loss,
        take_profit: shared.take_profit,
        max_hold_time: shared.max_hold_time,
        qty: shared.qty
    };
    Ok(strategy)
}

pub fn parse_decision_strategy(fields: &Fields) -> Result<Strategy<DecisionNet, DecisionPenalties, DecisionActions>, String> {
    let shared = parse_strategy_shared(fields)?;

    let net_fields = fields.child_fields(&["base_net"]);
    let base_net = parse_decision_net(&net_fields)?;

    let actions_fields = fields.child_fields(&["actions"]);
    let actions = parse_decision_actions(&actions_fields)?;

    let pen_fields = fields.child_fields(&["penalties"]);
    let penalties = parse_decision_penalties(&pen_fields)?;

    let strategy = Strategy {
        base_net,
        feats: shared.feats,
        actions,
        penalties,
        stop_conds: shared.stop_conds,
        opt: shared.opt,
        entry_ptr: shared.entry_ptr,
        exit_ptr: shared.exit_ptr,
        stop_loss: shared.stop_loss,
        take_profit: shared.take_profit,
        max_hold_time: shared.max_hold_time,
        qty: shared.qty
    };
    Ok(strategy)
}

// === Validation ===

fn validate_strategy_scalars<T, P, A>(strategy: &Strategy<T, P, A>) -> Result<(), String>
where
    T: Network,
    P: Penalties<T>,
    A: Actions<T>
{
    if strategy.stop_loss <= 0.0 {
        return Err("stop_loss must be > 0.0".to_string());
    }
    if strategy.take_profit <= 0.0 {
        return Err("take_profit must be > 0.0".to_string());
    }
    if strategy.max_hold_time == 0 {
        return Err("max_hold_time must be > 0".to_string());
    }
    if strategy.qty <= 0.0 {
        return Err("qty must be > 0.0".to_string());
    }
    Ok(())
}

fn validate_strategy_common<T, P, A>(strategy: &Strategy<T, P, A>) -> Result<(), String>
where
    T: Network,
    P: Penalties<T>,
    A: Actions<T>
{
    validate_strategy_scalars(strategy)?;
    validate_stop_conds(&strategy.stop_conds)?;
    validate_opt(&strategy.opt)?;
    Ok(())
}

pub fn validate_logic_strategy(strategy: &Strategy<LogicNet, LogicPenalties, LogicActions>) -> Result<(), String> {
    validate_strategy_common(strategy)?;
    let ids = feat_ids(&strategy.feats);
    validate_logic_net(&strategy.base_net, &ids)?;
    validate_logic_penalties(&strategy.penalties)?;
    validate_logic_actions(&strategy.actions, &strategy.feats)?;
    Ok(())
}

pub fn validate_decision_strategy(strategy: &Strategy<DecisionNet, DecisionPenalties, DecisionActions>) -> Result<(), String> {
    validate_strategy_common(strategy)?;
    let ids = feat_ids(&strategy.feats);
    validate_decision_net(&strategy.base_net, &ids)?;
    validate_decision_penalties(&strategy.penalties)?;
    validate_decision_actions(&strategy.actions, &strategy.feats)?;
    Ok(())
}
