use alphchemy_engine::experiment::strategy::{EntrySchema, ExitSchema, Strategy};
use alphchemy_engine::features::features::{Feature, feat_ids};
use alphchemy_engine::network::network::{NodePtr, Anchor};
use alphchemy_engine::network::logic_net::{LogicNet, LogicPenalties};
use alphchemy_engine::network::decision_net::{DecisionNet, DecisionPenalties};
use alphchemy_engine::actions::actions::{Action, Actions};
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

fn parse_node_ptr(fields: Option<Fields<'_>>) -> Result<NodePtr, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    if fields.option_usize(&["idx"])?.is_some() {
        return Err("node pointer idx was renamed to offset".to_string());
    }

    let anchor_text = fields.string(&["anchor"], "from_start")?;
    let anchor = parse_anchor(&anchor_text)?;
    let offset = fields.usize(&["offset"], 0)?;

    let node_ptr = NodePtr { anchor, offset };
    Ok(node_ptr)
}

// === Shared strategy parsing ===

struct StrategyShared {
    feats: Vec<Feature>,
    stop_conds: StopConds,
    entry_schema: EntrySchema,
    exit_schema: ExitSchema,
    qty: f64
}

fn parse_signal_schema(fields: &Fields<'_>) -> Result<(NodePtr, bool), String> {
    let long_ptr_fields = fields.child_fields(&["long_ptr"])?;
    let long_ptr = parse_node_ptr(long_ptr_fields)?;
    let strong_long = fields.bool(&["strong_long"], false)?;

    Ok((long_ptr, strong_long))
}

fn parse_strategy_shared(fields: &Fields) -> Result<StrategyShared, String> {
    if fields.child_fields(&["entry_ptr"])?.is_some() {
        return Err("entry_ptr was replaced by entry.long_ptr".to_string());
    }
    if fields.child_fields(&["exit_ptr"])?.is_some() {
        return Err("exit_ptr was replaced by exit.long_ptr".to_string());
    }
    if fields.option_string(&["strong_entry"])?.is_some() {
        return Err("strong_entry was replaced by entry.strong_long".to_string());
    }
    if fields.option_string(&["strong_exit"])?.is_some() {
        return Err("strong_exit was replaced by exit.strong_long".to_string());
    }

    let feat_fields = fields.child_fields(&["feats"])?;
    let feats = parse_feats(feat_fields)?;

    let stop_fields = fields.child_fields(&["stop_conds"])?;
    let stop_conds = parse_stop_conds(stop_fields)?;

    let entry_fields = fields.child_fields(&["entry", "entry_schema"])?;
    let default_entry_fields = Fields { entries: Vec::new() };
    let entry_fields = entry_fields.as_ref().unwrap_or(&default_entry_fields);
    let (entry_long_ptr, strong_entry_long) = parse_signal_schema(entry_fields)?;
    let entry_schema = EntrySchema { entry_long_ptr, strong_entry_long };
    let exit_fields = fields.child_fields(&["exit", "exit_schema"])?;
    let default_exit_fields = Fields { entries: Vec::new() };
    let exit_fields = exit_fields.as_ref().unwrap_or(&default_exit_fields);
    let (exit_long_ptr, strong_exit_long) = parse_signal_schema(exit_fields)?;
    let stop_loss = exit_fields.f64(&["stop_loss"], 0.04)?;
    let take_profit = exit_fields.f64(&["take_profit"], 0.08)?;
    let max_hold_time = exit_fields.usize(&["max_hold_time"], 72)?;
    let exit_schema = ExitSchema {
        exit_long_ptr, strong_exit_long, stop_loss, take_profit, max_hold_time
    };
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
        feats, stop_conds, entry_schema, exit_schema, qty
    };
    Ok(shared)
}

fn parse_strategy_opt(fields: &Fields, actions_list: &[Action]) -> Result<GeneticOpt, String> {
    let opt_fields = fields.child_fields(&["opt"])?;
    parse_opt(opt_fields, actions_list)
}

// === Strategy parsing ===

pub fn parse_logic_strategy(fields: Option<Fields<'_>>) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let shared = parse_strategy_shared(&fields)?;
    let ids = feat_ids(&shared.feats);

    let net_fields = fields.child_fields(&["base_net", "base_network", "initial_net", "initial_network"])?;
    let base_net = parse_logic_net(net_fields, &ids)?;

    let actions_fields = fields.child_fields(&["actions"])?;
    let actions = parse_logic_actions(actions_fields, &shared.feats)?;
    let actions_list = actions.actions_list();
    let opt = parse_strategy_opt(&fields, &actions_list)?;

    let penalties_fields = fields.child_fields(&["penalties"])?;
    let penalties = parse_logic_penalties(penalties_fields)?;

    Ok(Strategy {
        base_net,
        feats: shared.feats,
        actions,
        penalties,
        stop_conds: shared.stop_conds,
        opt,
        entry_schema: shared.entry_schema,
        exit_schema: shared.exit_schema,
        qty: shared.qty
    })
}

pub fn parse_decision_strategy(fields: Option<Fields<'_>>) -> Result<Strategy<DecisionNet, DecisionPenalties, DecisionActions>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let shared = parse_strategy_shared(&fields)?;
    let ids = feat_ids(&shared.feats);

    let net_fields = fields.child_fields(&["base_net", "base_network", "initial_net", "initial_network"])?;
    let base_net = parse_decision_net(net_fields, &ids)?;

    let actions_fields = fields.child_fields(&["actions"])?;
    let actions = parse_decision_actions(actions_fields, &shared.feats)?;
    let actions_list = actions.actions_list();
    let opt = parse_strategy_opt(&fields, &actions_list)?;

    let penalties_fields = fields.child_fields(&["penalties"])?;
    let penalties = parse_decision_penalties(penalties_fields)?;

    Ok(Strategy {
        base_net,
        feats: shared.feats,
        actions,
        penalties,
        stop_conds: shared.stop_conds,
        opt,
        entry_schema: shared.entry_schema,
        exit_schema: shared.exit_schema,
        qty: shared.qty
    })
}
