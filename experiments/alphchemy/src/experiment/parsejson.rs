use std::collections::{HashMap, HashSet};

use serde_json::Value;

use crate::features::features::{Feature, Constant, RawReturns, OHLC};
use crate::network::network::{Anchor, NodePtr};
use crate::network::logic_net::{LogicNet, LogicNode, LogicPenalties, Gate, InputNode, GateNode};
use crate::network::decision_net::{DecisionNet, DecisionNode, DecisionPenalties, BranchNode, RefNode};
use crate::actions::actions::{Action, ThresholdRange};
use crate::actions::logic_actions::LogicActions;
use crate::actions::decision_actions::DecisionActions;
use crate::optimizer::optimizer::StopConds;
use crate::optimizer::genetic::GeneticOpt;

use super::strategy::Strategy;
use super::backtest::BacktestSchema;
use super::experiment::Experiment;

// --- helpers ---

fn get_str<'a>(json: &'a Value, key: &str) -> Result<&'a str, String> {
    json.get(key)
        .and_then(|v| v.as_str())
        .ok_or_else(|| format!("missing or invalid string field: {key}"))
}

fn get_f64(json: &Value, key: &str) -> Result<f64, String> {
    json.get(key)
        .and_then(|v| v.as_f64())
        .ok_or_else(|| format!("missing or invalid float field: {key}"))
}

fn get_u64(json: &Value, key: &str) -> Result<u64, String> {
    json.get(key)
        .and_then(|v| v.as_u64())
        .ok_or_else(|| format!("missing or invalid integer field: {key}"))
}

fn get_i64(json: &Value, key: &str) -> Result<i64, String> {
    json.get(key)
        .and_then(|v| v.as_i64())
        .ok_or_else(|| format!("missing or invalid integer field: {key}"))
}

fn get_bool(json: &Value, key: &str) -> Result<bool, String> {
    json.get(key)
        .and_then(|v| v.as_bool())
        .ok_or_else(|| format!("missing or invalid boolean field: {key}"))
}

fn get_array<'a>(json: &'a Value, key: &str) -> Result<&'a Vec<Value>, String> {
    json.get(key)
        .and_then(|v| v.as_array())
        .ok_or_else(|| format!("missing or invalid array field: {key}"))
}

fn get_object<'a>(json: &'a Value, key: &str) -> Result<&'a Value, String> {
    json.get(key)
        .filter(|v| v.is_object())
        .ok_or_else(|| format!("missing or invalid object field: {key}"))
}

// --- index parsing: 0-based, negative means unset ---

fn parse_idx(json: &Value, key: &str) -> Result<Option<usize>, String> {
    let val = get_i64(json, key)?;
    if val >= 0 {
        Ok(Some(val as usize))
    } else {
        Ok(None)
    }
}

// --- features ---

fn parse_ohlc(s: &str) -> Result<OHLC, String> {
    match s {
        "open" => Ok(OHLC::Open),
        "high" => Ok(OHLC::High),
        "low" => Ok(OHLC::Low),
        "close" => Ok(OHLC::Close),
        _ => Err(format!("invalid ohlc: {s}"))
    }
}

pub fn parse_feat(json: &Value) -> Result<Box<dyn Feature>, String> {
    let feature = get_str(json, "feature")?;
    let id = get_str(json, "id")?.to_string();

    match feature {
        "constant" => {
            let constant = get_f64(json, "constant")?;
            Ok(Box::new(Constant { id, constant }))
        }
        "raw returns" => {
            let returns_type = get_str(json, "returns_type")?;
            let log_returns = match returns_type {
                "log" => true,
                "simple" => false,
                _ => return Err(format!("invalid returns_type: {returns_type}"))
            };
            let ohlc = parse_ohlc(get_str(json, "ohlc")?)?;
            Ok(Box::new(RawReturns { id, log_returns, ohlc }))
        }
        _ => Err(format!("unsupported feature: {feature}"))
    }
}

fn validate_feat_ids(feats: &[Box<dyn Feature>]) -> Result<(), String> {
    let mut ids = HashSet::new();
    for feat in feats {
        if !ids.insert(feat.id()) {
            return Err(format!("duplicate feature id: {}", feat.id()));
        }
    }
    Ok(())
}

// --- node pointers ---

fn parse_anchor(s: &str) -> Result<Anchor, String> {
    match s {
        "from_start" => Ok(Anchor::FromStart),
        "from_end" => Ok(Anchor::FromEnd),
        _ => Err(format!("invalid anchor: {s}"))
    }
}

pub fn parse_node_ptr(json: &Value) -> Result<NodePtr, String> {
    let anchor = parse_anchor(get_str(json, "anchor")?)?;
    let idx = get_u64(json, "idx")? as usize;
    Ok(NodePtr { anchor, idx })
}

// --- gates ---

fn parse_gate(s: &str) -> Result<Gate, String> {
    match s {
        "AND" => Ok(Gate::And),
        "OR" => Ok(Gate::Or),
        "XOR" => Ok(Gate::Xor),
        "NAND" => Ok(Gate::Nand),
        "NOR" => Ok(Gate::Nor),
        "XNOR" => Ok(Gate::Xnor),
        _ => Err(format!("invalid gate: {s}"))
    }
}

// --- logic nodes ---

fn parse_logic_node(json: &Value, n_feats: usize, n_nodes: usize) -> Result<LogicNode, String> {
    let node_type = get_str(json, "type")?;

    match node_type {
        "input" => {
            let threshold = Some(get_f64(json, "threshold")?);
            let feat_idx = parse_idx(json, "feat_idx")?;

            if let Some(idx) = feat_idx {
                if idx >= n_feats {
                    return Err("feat_idx out of range".to_string());
                }
            }

            Ok(LogicNode::Input(InputNode {
                threshold,
                feat_idx,
                value: false
            }))
        }
        "logic" => {
            let gate = Some(parse_gate(get_str(json, "gate")?)?);
            let in1_idx = parse_idx(json, "in1_idx")?;
            let in2_idx = parse_idx(json, "in2_idx")?;

            if let Some(idx) = in1_idx {
                if idx >= n_nodes {
                    return Err("in1_idx out of range".to_string());
                }
            }
            if let Some(idx) = in2_idx {
                if idx >= n_nodes {
                    return Err("in2_idx out of range".to_string());
                }
            }

            Ok(LogicNode::Gate(GateNode {
                gate,
                in1_idx,
                in2_idx,
                value: false
            }))
        }
        _ => Err(format!("invalid logic node type: {node_type}"))
    }
}

// --- decision nodes ---

fn parse_decision_node(json: &Value, n_feats: usize, n_nodes: usize) -> Result<DecisionNode, String> {
    let node_type = get_str(json, "type")?;

    let true_idx = parse_idx(json, "true_idx")?;
    let false_idx = parse_idx(json, "false_idx")?;

    if let Some(idx) = true_idx {
        if idx >= n_nodes {
            return Err("true_idx out of range".to_string());
        }
    }
    if let Some(idx) = false_idx {
        if idx >= n_nodes {
            return Err("false_idx out of range".to_string());
        }
    }

    match node_type {
        "branch" => {
            let threshold = Some(get_f64(json, "threshold")?);
            let feat_idx = parse_idx(json, "feat_idx")?;

            if let Some(idx) = feat_idx {
                if idx >= n_feats {
                    return Err("feat_idx out of range".to_string());
                }
            }

            Ok(DecisionNode::Branch(BranchNode {
                threshold,
                feat_idx,
                true_idx,
                false_idx,
                value: false
            }))
        }
        "ref" => {
            let ref_idx = parse_idx(json, "ref_idx")?;

            if let Some(idx) = ref_idx {
                if idx >= n_nodes {
                    return Err("ref_idx out of range".to_string());
                }
            }

            Ok(DecisionNode::Ref(RefNode {
                ref_idx,
                true_idx,
                false_idx,
                value: false
            }))
        }
        _ => Err(format!("invalid decision node type: {node_type}"))
    }
}

// --- networks ---

fn parse_logic_net(json: &Value, n_feats: usize) -> Result<LogicNet, String> {
    let nodes_json = get_array(json, "nodes")?;
    let default_value = get_bool(json, "default_value")?;
    let n_nodes = nodes_json.len();

    let mut nodes = Vec::with_capacity(n_nodes);
    for node_json in nodes_json {
        nodes.push(parse_logic_node(node_json, n_feats, n_nodes)?);
    }

    Ok(LogicNet { nodes, default_value })
}

fn parse_decision_net(json: &Value, n_feats: usize) -> Result<DecisionNet, String> {
    let nodes_json = get_array(json, "nodes")?;
    let default_value = get_bool(json, "default_value")?;
    let max_trail_len = get_u64(json, "max_trail_len")? as usize;
    let n_nodes = nodes_json.len();

    if max_trail_len == 0 {
        return Err("max_trail_len must be > 0".to_string());
    }

    let mut nodes = Vec::with_capacity(n_nodes);
    for node_json in nodes_json {
        nodes.push(parse_decision_node(node_json, n_feats, n_nodes)?);
    }

    Ok(DecisionNet {
        nodes,
        idx_trail: Vec::new(),
        max_trail_len,
        default_value
    })
}

// --- penalties ---

fn parse_logic_penalties(json: &Value) -> Result<LogicPenalties, String> {
    let node = get_f64(json, "node")?;
    let input = get_f64(json, "input")?;
    let gate = get_f64(json, "logic")?;
    let recurrence = get_f64(json, "recurrence")?;
    let feedforward = get_f64(json, "feedforward")?;
    let used_feat = get_f64(json, "used_feat")?;
    let unused_feat = get_f64(json, "unused_feat")?;

    if node < 0.0 { return Err("node penalty must be >= 0.0".to_string()); }
    if input < 0.0 { return Err("input penalty must be >= 0.0".to_string()); }
    if gate < 0.0 { return Err("logic penalty must be >= 0.0".to_string()); }
    if recurrence < 0.0 { return Err("recurrence penalty must be >= 0.0".to_string()); }
    if feedforward < 0.0 { return Err("feedforward penalty must be >= 0.0".to_string()); }
    if used_feat < 0.0 { return Err("used_feat penalty must be >= 0.0".to_string()); }
    if unused_feat < 0.0 { return Err("unused_feat penalty must be >= 0.0".to_string()); }

    Ok(LogicPenalties { node, input, gate, recurrence, feedforward, used_feat, unused_feat })
}

fn parse_decision_penalties(json: &Value) -> Result<DecisionPenalties, String> {
    let node = get_f64(json, "node")?;
    let branch = get_f64(json, "branch")?;
    let ref_ = get_f64(json, "ref")?;
    let leaf = get_f64(json, "leaf")?;
    let non_leaf = get_f64(json, "non_leaf")?;
    let used_feat = get_f64(json, "used_feat")?;
    let unused_feat = get_f64(json, "unused_feat")?;

    if node < 0.0 { return Err("node penalty must be >= 0.0".to_string()); }
    if branch < 0.0 { return Err("branch penalty must be >= 0.0".to_string()); }
    if ref_ < 0.0 { return Err("ref penalty must be >= 0.0".to_string()); }
    if leaf < 0.0 { return Err("leaf penalty must be >= 0.0".to_string()); }
    if non_leaf < 0.0 { return Err("non_leaf penalty must be >= 0.0".to_string()); }
    if used_feat < 0.0 { return Err("used_feat penalty must be >= 0.0".to_string()); }
    if unused_feat < 0.0 { return Err("unused_feat penalty must be >= 0.0".to_string()); }

    Ok(DecisionPenalties { node, branch, ref_, leaf, non_leaf, used_feat, unused_feat })
}

// --- actions ---

fn parse_action(s: &str) -> Result<Action, String> {
    match s {
        "NextFeat" => Ok(Action::NextFeat),
        "NextThreshold" => Ok(Action::NextThreshold),
        "NextNode" => Ok(Action::NextNode),
        "SelectNode" => Ok(Action::SelectNode),
        "NextGate" => Ok(Action::NextGate),
        "SetFeatIdx" => Ok(Action::SetFeatIdx),
        "SetThreshold" => Ok(Action::SetThreshold),
        "SetGate" => Ok(Action::SetGate),
        "SetIn1Idx" => Ok(Action::SetIn1Idx),
        "SetIn2Idx" => Ok(Action::SetIn2Idx),
        "SetTrueIdx" => Ok(Action::SetTrueIdx),
        "SetFalseIdx" => Ok(Action::SetFalseIdx),
        "SetRefIdx" => Ok(Action::SetRefIdx),
        "NewInput" => Ok(Action::NewInput),
        "NewGate" => Ok(Action::NewGate),
        "NewBranch" => Ok(Action::NewBranch),
        "NewRef" => Ok(Action::NewRef),
        _ => Err(format!("invalid action: {s}"))
    }
}

fn parse_meta_actions(json: &Value) -> Result<HashMap<Action, Vec<Action>>, String> {
    let arr = json.as_array()
        .ok_or_else(|| "meta_actions must be an array".to_string())?;

    let mut meta_actions = HashMap::new();
    let mut labels = Vec::new();
    let mut all_sub_actions = Vec::new();

    for meta_json in arr {
        let label = parse_action(get_str(meta_json, "label")?)?;
        let sub_actions_json = get_array(meta_json, "sub_actions")?;

        let sub_actions: Vec<Action> = sub_actions_json.iter()
            .map(|v| {
                let s = v.as_str().ok_or_else(|| "sub_action must be a string".to_string())?;
                parse_action(s)
            })
            .collect::<Result<Vec<_>, _>>()?;

        labels.push(label);
        all_sub_actions.extend_from_slice(&sub_actions);
        meta_actions.insert(label, sub_actions);
    }

    let labels_set: HashSet<Action> = labels.into_iter().collect();
    let sub_set: HashSet<Action> = all_sub_actions.into_iter().collect();

    if !labels_set.is_disjoint(&sub_set) {
        return Err("sub action cannot be a meta action".to_string());
    }

    Ok(meta_actions)
}

fn parse_thresholds(json: &Value, feats: &[Box<dyn Feature>]) -> Result<Vec<ThresholdRange>, String> {
    let arr = json.as_array()
        .ok_or_else(|| "thresholds must be an array".to_string())?;

    let n_features = feats.len();
    if arr.len() != n_features {
        return Err("length of thresholds must be == # of features".to_string());
    }

    let mut thresholds = vec![ThresholdRange { min: 0.0, max: 0.0 }; n_features];

    for threshold_json in arr {
        let feat_id = get_str(threshold_json, "feat_id")?;
        let idx = feats.iter().position(|f| f.id() == feat_id)
            .ok_or_else(|| format!("feature with id \"{feat_id}\" not found"))?;

        let min = get_f64(threshold_json, "min")?;
        let max = get_f64(threshold_json, "max")?;

        if max <= min {
            return Err("threshold max must be > min".to_string());
        }

        thresholds[idx] = ThresholdRange { min, max };
    }

    Ok(thresholds)
}

fn parse_logic_actions(json: &Value, feats: &[Box<dyn Feature>]) -> Result<LogicActions, String> {
    let meta_actions = parse_meta_actions(json.get("meta_actions")
        .ok_or_else(|| "missing meta_actions".to_string())?)?;

    let thresholds = parse_thresholds(json.get("thresholds")
        .ok_or_else(|| "missing thresholds".to_string())?, feats)?;

    let n_thresholds = get_u64(json, "n_thresholds")? as usize;
    if n_thresholds == 0 {
        return Err("n_thresholds must be > 0".to_string());
    }

    let allow_recurrence = get_bool(json, "allow_recurrence")?;

    let mut allowed_gates = Vec::new();
    if get_bool(json, "allow_and").unwrap_or(false) { allowed_gates.push(Gate::And); }
    if get_bool(json, "allow_or").unwrap_or(false) { allowed_gates.push(Gate::Or); }
    if get_bool(json, "allow_xor").unwrap_or(false) { allowed_gates.push(Gate::Xor); }
    if get_bool(json, "allow_nand").unwrap_or(false) { allowed_gates.push(Gate::Nand); }
    if get_bool(json, "allow_nor").unwrap_or(false) { allowed_gates.push(Gate::Nor); }
    if get_bool(json, "allow_xnor").unwrap_or(false) { allowed_gates.push(Gate::Xnor); }

    Ok(LogicActions {
        meta_actions,
        thresholds,
        n_thresholds,
        allow_recurrence,
        allowed_gates
    })
}

fn parse_decision_actions(json: &Value, feats: &[Box<dyn Feature>]) -> Result<DecisionActions, String> {
    let meta_actions = parse_meta_actions(json.get("meta_actions")
        .ok_or_else(|| "missing meta_actions".to_string())?)?;

    let thresholds = parse_thresholds(json.get("thresholds")
        .ok_or_else(|| "missing thresholds".to_string())?, feats)?;

    let n_thresholds = get_u64(json, "n_thresholds")? as usize;
    if n_thresholds == 0 {
        return Err("n_thresholds must be > 0".to_string());
    }

    let allow_refs = get_bool(json, "allow_refs")?;

    Ok(DecisionActions {
        meta_actions,
        thresholds,
        n_thresholds,
        allow_refs
    })
}

// --- optimizer ---

fn parse_stop_conds(json: &Value) -> Result<StopConds, String> {
    let max_iters = get_u64(json, "max_iters")? as usize;
    let train_patience = get_u64(json, "train_patience")? as usize;
    let val_patience = get_u64(json, "val_patience")? as usize;

    if max_iters == 0 { return Err("max_iters must be > 0".to_string()); }

    Ok(StopConds { max_iters, train_patience, val_patience })
}

fn parse_opt(json: &Value) -> Result<GeneticOpt, String> {
    let opt_type = get_str(json, "type")?;

    if opt_type != "genetic" {
        return Err(format!("invalid optimizer type: {opt_type}"));
    }

    let pop_size = get_u64(json, "pop_size")? as usize;
    let seq_len = get_u64(json, "seq_len")? as usize;
    let n_elites = get_u64(json, "n_elites")? as usize;
    let mut_rate = get_f64(json, "mut_rate")?;
    let cross_rate = get_f64(json, "cross_rate")?;
    let tourn_size = get_u64(json, "tournament_size")? as usize;

    if pop_size == 0 { return Err("pop_size must be > 0".to_string()); }
    if seq_len == 0 { return Err("seq_len must be > 0".to_string()); }
    if n_elites > pop_size { return Err("n_elites must be 0 - population size".to_string()); }
    if !(0.0..=1.0).contains(&mut_rate) { return Err("mut_rate must be 0.0 - 1.0".to_string()); }
    if !(0.0..=1.0).contains(&cross_rate) { return Err("cross_rate must be 0.0 - 1.0".to_string()); }
    if tourn_size == 0 || tourn_size > pop_size { return Err("tournament_size must be 1 - pop_size".to_string()); }

    Ok(GeneticOpt { pop_size, seq_len, n_elites, mut_rate, cross_rate, tourn_size })
}

// --- backtest schema ---

pub fn parse_backtest_schema(json: &Value) -> Result<BacktestSchema, String> {
    let start_offset = get_u64(json, "start_offset")? as usize;
    let start_balance = get_f64(json, "start_balance")?;
    let alloc_size = get_f64(json, "alloc_size")?;
    let delay = get_u64(json, "delay")? as usize;

    if start_balance <= 0.0 { return Err("start_balance must be > 0.0".to_string()); }
    if alloc_size <= 0.0 || alloc_size > 1.0 { return Err("alloc_size must be > 0.0 and <= 1.0".to_string()); }

    Ok(BacktestSchema { start_offset, start_balance, alloc_size, delay })
}

// --- strategy ---

fn parse_logic_strategy(json: &Value) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let feats_json = get_array(json, "feats")?;
    let feats: Vec<Box<dyn Feature>> = feats_json.iter()
        .map(|fj| parse_feat(fj))
        .collect::<Result<Vec<_>, _>>()?;
    let n_feats = feats.len();

    validate_feat_ids(&feats)?;

    let base_net = parse_logic_net(get_object(json, "base_net")?, n_feats)?;
    let actions = parse_logic_actions(get_object(json, "actions")?, &feats)?;
    let penalties = parse_logic_penalties(get_object(json, "penalties")?)?;
    let stop_conds = parse_stop_conds(get_object(json, "stop_conds")?)?;
    let opt = parse_opt(get_object(json, "opt")?)?;
    let entry_ptr = parse_node_ptr(get_object(json, "entry_ptr")?)?;
    let exit_ptr = parse_node_ptr(get_object(json, "exit_ptr")?)?;

    let stop_loss = get_f64(json, "stop_loss")?;
    let take_profit = get_f64(json, "take_profit")?;
    let max_hold_time = get_u64(json, "max_hold_time")? as usize;

    if stop_loss <= 0.0 { return Err("stop_loss must be > 0.0".to_string()); }
    if take_profit <= 0.0 { return Err("take_profit must be > 0.0".to_string()); }
    if max_hold_time == 0 { return Err("max_hold_time must be > 0".to_string()); }

    Ok(Strategy {
        base_net,
        feats,
        actions,
        penalties,
        stop_conds,
        opt,
        entry_ptr,
        exit_ptr,
        stop_loss,
        take_profit,
        max_hold_time
    })
}

fn parse_decision_strategy(json: &Value) -> Result<Strategy<DecisionNet, DecisionPenalties, DecisionActions>, String> {
    let feats_json = get_array(json, "feats")?;
    let feats: Vec<Box<dyn Feature>> = feats_json.iter()
        .map(|fj| parse_feat(fj))
        .collect::<Result<Vec<_>, _>>()?;
    let n_feats = feats.len();

    validate_feat_ids(&feats)?;

    let base_net = parse_decision_net(get_object(json, "base_net")?, n_feats)?;
    let actions = parse_decision_actions(get_object(json, "actions")?, &feats)?;
    let penalties = parse_decision_penalties(get_object(json, "penalties")?)?;
    let stop_conds = parse_stop_conds(get_object(json, "stop_conds")?)?;
    let opt = parse_opt(get_object(json, "opt")?)?;
    let entry_ptr = parse_node_ptr(get_object(json, "entry_ptr")?)?;
    let exit_ptr = parse_node_ptr(get_object(json, "exit_ptr")?)?;

    let stop_loss = get_f64(json, "stop_loss")?;
    let take_profit = get_f64(json, "take_profit")?;
    let max_hold_time = get_u64(json, "max_hold_time")? as usize;

    if stop_loss <= 0.0 { return Err("stop_loss must be > 0.0".to_string()); }
    if take_profit <= 0.0 { return Err("take_profit must be > 0.0".to_string()); }
    if max_hold_time == 0 { return Err("max_hold_time must be > 0".to_string()); }

    Ok(Strategy {
        base_net,
        feats,
        actions,
        penalties,
        stop_conds,
        opt,
        entry_ptr,
        exit_ptr,
        stop_loss,
        take_profit,
        max_hold_time
    })
}

// --- experiment ---

pub enum ExperimentVariant {
    Logic(Experiment<LogicNet, LogicPenalties, LogicActions>),
    Decision(Experiment<DecisionNet, DecisionPenalties, DecisionActions>)
}

pub fn parse_experiment(json: &Value) -> Result<ExperimentVariant, String> {
    let val_size = get_f64(json, "val_size")?;
    let test_size = get_f64(json, "test_size")?;
    let cv_folds = get_u64(json, "cv_folds")? as usize;
    let fold_size = get_f64(json, "fold_size")?;

    if val_size <= 0.0 { return Err("val_size must be > 0.0".to_string()); }
    if test_size <= 0.0 { return Err("test_size must be > 0.0".to_string()); }
    if val_size + test_size >= 1.0 { return Err("val_size + test_size must be < 1.0".to_string()); }
    if cv_folds == 0 { return Err("cv_folds must be > 0".to_string()); }
    if fold_size <= 0.0 || fold_size > 1.0 { return Err("fold_size must be > 0.0 and <= 1.0".to_string()); }

    let backtest_schema = parse_backtest_schema(get_object(json, "backtest_schema")?)?;

    let strategy_json = get_object(json, "strategy")?;
    let net_type = get_str(get_object(strategy_json, "base_net")?, "type")?;

    match net_type {
        "logic" => {
            let strategy = parse_logic_strategy(strategy_json)?;
            Ok(ExperimentVariant::Logic(Experiment {
                val_size,
                test_size,
                cv_folds,
                fold_size,
                backtest_schema,
                strategy
            }))
        }
        "decision" => {
            let strategy = parse_decision_strategy(strategy_json)?;
            Ok(ExperimentVariant::Decision(Experiment {
                val_size,
                test_size,
                cv_folds,
                fold_size,
                backtest_schema,
                strategy
            }))
        }
        _ => Err(format!("invalid network type: {net_type}"))
    }
}
