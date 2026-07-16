use alphchemy_engine::experiment::strategy::Strategy;
use alphchemy_engine::features::features::{Feature, feat_ids};
use alphchemy_engine::network::network::{NodePtr, Anchor};
use alphchemy_engine::network::logic_net::{LogicNet, LogicPenalties};
use alphchemy_engine::network::decision_net::{DecisionNet, DecisionPenalties};
use alphchemy_engine::actions::logic_actions::LogicActions;
use alphchemy_engine::actions::decision_actions::DecisionActions;
use alphchemy_engine::optimizer::optimizer::StopConds;
use alphchemy_engine::optimizer::genetic::GeneticOpt;
use super::parse::Fields;
use super::parse_features::parse_feats;
use super::parse_net::{parse_logic_net, parse_decision_net, parse_logic_penalties, parse_decision_penalties};
use super::parse_actions::{parse_logic_actions, parse_decision_actions};
use super::parse_optimizer::{parse_stop_conds, parse_opt};

// === Node pointer parsing ===

fn parse_anchor(text: &str) -> Result<Anchor, String> {
    match text {
        "from_start" => Ok(Anchor::FromStart),
        "from_end" => Ok(Anchor::FromEnd),
        _ => Err(format!("invalid anchor: {text}"))
    }
}

fn parse_node_ptr(fields: &Fields<'_>) -> Result<NodePtr, String> {
    if fields.opt_usize(&["idx"])?.is_some() {
        return Err("node pointer idx was renamed to offset".to_string());
    }

    let anchor_text = fields.string(&["anchor"], "from_start");
    let anchor = parse_anchor(&anchor_text)?;
    let offset = fields.usize(&["offset"], 0)?;

    let node_ptr = NodePtr { anchor, offset };
    Ok(node_ptr)
}

// === Shared strategy parsing ===

struct StrategyShared {
    feats: Vec<Feature>,
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

    if stop_loss <= 0.0 {
        return Err("stop_loss must be > 0.0".to_string());
    }
    if take_profit <= 0.0 {
        return Err("take_profit must be > 0.0".to_string());
    }
    if max_hold_time == 0 {
        return Err("max_hold_time must be > 0".to_string());
    }
    if qty <= 0.0 {
        return Err("qty must be > 0.0".to_string());
    }

    let shared = StrategyShared {
        feats, stop_conds, opt, entry_ptr, exit_ptr, stop_loss, take_profit, max_hold_time, qty
    };
    Ok(shared)
}

// === Strategy parsing ===

pub fn parse_logic_strategy(fields: &Fields) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let shared = parse_strategy_shared(fields)?;
    let ids = feat_ids(&shared.feats);

    let net_fields = fields.child_fields(&["base_net"]);
    let base_net = parse_logic_net(&net_fields, &ids)?;

    let actions_fields = fields.child_fields(&["actions"]);
    let actions = parse_logic_actions(&actions_fields, &shared.feats)?;

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
    let ids = feat_ids(&shared.feats);

    let net_fields = fields.child_fields(&["base_net"]);
    let base_net = parse_decision_net(&net_fields, &ids)?;

    let actions_fields = fields.child_fields(&["actions"]);
    let actions = parse_decision_actions(&actions_fields, &shared.feats)?;

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
