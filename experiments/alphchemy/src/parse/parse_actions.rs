use std::collections::{HashMap, HashSet};

use crate::features::features::{Feature, feat_ids};
use crate::actions::actions::{Action, ThresholdRange};
use crate::actions::logic_actions::LogicActions;
use crate::actions::decision_actions::DecisionActions;
use crate::network::logic_net::Gate;
use super::parse::Fields;
use super::parse_net::parse_gate;

// === Action parsing ===

pub fn parse_action(text: &str, meta_actions: Option<&HashMap<String, Vec<Action>>>) -> Result<Action, String> {
    match text {
        "next_feat" => Ok(Action::NextFeat),
        "next_threshold" => Ok(Action::NextThreshold),
        "next_node" => Ok(Action::NextNode),
        "select_node" => Ok(Action::SelectNode),
        "next_gate" => Ok(Action::NextGate),
        "set_feat" => Ok(Action::SetFeat),
        "set_threshold" => Ok(Action::SetThreshold),
        "set_gate" => Ok(Action::SetGate),
        "set_in1_idx" => Ok(Action::SetIn1Idx),
        "set_in2_idx" => Ok(Action::SetIn2Idx),
        "set_true_idx" => Ok(Action::SetTrueIdx),
        "set_false_idx" => Ok(Action::SetFalseIdx),
        "set_ref_idx" => Ok(Action::SetRefIdx),
        "new_input" => Ok(Action::NewInput),
        "new_gate" => Ok(Action::NewGate),
        "new_branch" => Ok(Action::NewBranch),
        "new_ref" => Ok(Action::NewRef),
        _ => {
            if let Some(actions) = meta_actions && actions.contains_key(text) {
                return Ok(Action::MetaAction(text.to_string()));
            }
            Err(format!("invalid action: {text}"))
        }
    }
}

fn parse_actions(texts: &[String]) -> Result<Vec<Action>, String> {
    let mut actions = Vec::with_capacity(texts.len());

    for text in texts {
        let action = parse_action(text, None)?;
        actions.push(action);
    }

    Ok(actions)
}

// === Shared section parsing ===

fn parse_meta_actions(fields: &Fields<'_>) -> Result<HashMap<String, Vec<Action>>, String> {
    let mut meta_actions = HashMap::new();

    for entry in &fields.entries {
        if parse_action(entry.key, None).is_ok() {
            return Err(format!("meta action label conflicts with built-in action: {}", entry.key));
        }

        let sub_fields = Fields::from_lines(&entry.children);
        let sub_action_texts = sub_fields.string_list(&["sub_actions"])?;
        let sub_actions = parse_actions(&sub_action_texts)?;
        meta_actions.insert(entry.key.to_string(), sub_actions);
    }

    Ok(meta_actions)
}

fn parse_thresholds(fields: &Fields<'_>) -> Result<HashMap<String, ThresholdRange>, String> {
    let mut thresholds = HashMap::new();

    for entry in &fields.entries {
        let range_fields = Fields::from_lines(&entry.children);
        let min = range_fields.f64(&["min"], 0.0)?;
        let max = range_fields.f64(&["max"], 0.0)?;
        let feat_id = entry.key.to_string();

        if thresholds.contains_key(&feat_id) {
            return Err(format!("duplicate threshold for feature id \"{feat_id}\""));
        }

        let range = ThresholdRange { min, max };
        thresholds.insert(feat_id, range);
    }

    Ok(thresholds)
}

fn parse_gates(texts: &[String]) -> Result<Vec<Gate>, String> {
    if texts.is_empty() {
        return Ok(vec![Gate::And, Gate::Or, Gate::Xor]);
    }

    let mut gates = Vec::with_capacity(texts.len());
    for text in texts {
        let gate = parse_gate(text)?;
        gates.push(gate);
    }

    Ok(gates)
}

// === Validation helpers ===

fn validate_thresholds(thresholds: &HashMap<String, ThresholdRange>, feats: &[Feature]) -> Result<(), String> {
    let ids = feat_ids(feats);
    let id_set = ids.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();

    if thresholds.len() != ids.len() {
        return Err("length of thresholds must be == # of features".to_string());
    }

    for (feat_id, range) in thresholds {
        if !id_set.contains(feat_id.as_str()) {
            return Err(format!("feature with id \"{feat_id}\" not found"));
        }
        if range.max <= range.min {
            return Err(format!("threshold for feature id \"{feat_id}\" max must be > min"));
        }
    }

    Ok(())
}

fn validate_feat_order(feat_order: &[String], feats: &[Feature]) -> Result<(), String> {
    let ids = feat_ids(feats);
    let id_set = ids.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();
    let mut order_set = HashSet::new();

    for feat_id in feat_order {
        if !id_set.contains(feat_id.as_str()) {
            return Err(format!("feature with id \"{feat_id}\" not found"));
        }
        if !order_set.insert(feat_id.as_str()) {
            return Err("feat_order cannot contain duplicate feature ids".to_string());
        }
    }

    Ok(())
}

pub fn parse_logic_actions(fields: &Fields, feats: &[Feature]) -> Result<LogicActions, String> {
    let meta_fields = fields.child_fields(&["meta_actions"]);
    let meta_actions = parse_meta_actions(&meta_fields)?;

    let threshold_fields = fields.child_fields(&["thresholds"]);
    let thresholds = parse_thresholds(&threshold_fields)?;

    let n_thresholds = fields.usize(&["n_thresholds"], 5)?;
    let feat_order = fields.string_list(&["feat_order"])?;
    let allow_recurrence = fields.bool(&["allow_recurrence"], false)?;
    let gate_texts = fields.string_list(&["allowed_gates"])?;
    let allowed_gates = parse_gates(&gate_texts)?;

    if n_thresholds == 0 {
        return Err("n_thresholds must be > 0".to_string());
    }
    validate_thresholds(&thresholds, feats)?;
    validate_feat_order(&feat_order, feats)?;

    let actions = LogicActions { meta_actions, thresholds, n_thresholds, feat_order, allow_recurrence, allowed_gates };
    Ok(actions)
}

pub fn parse_decision_actions(fields: &Fields, feats: &[Feature]) -> Result<DecisionActions, String> {
    let meta_fields = fields.child_fields(&["meta_actions"]);
    let meta_actions = parse_meta_actions(&meta_fields)?;
    let threshold_fields = fields.child_fields(&["thresholds"]);
    let thresholds = parse_thresholds(&threshold_fields)?;

    let n_thresholds = fields.usize(&["n_thresholds"], 5)?;
    let feat_order = fields.string_list(&["feat_order"])?;

    let allow_refs = fields.bool(&["allow_refs"], false)?;

    if n_thresholds == 0 {
        return Err("n_thresholds must be > 0".to_string());
    }
    validate_thresholds(&thresholds, feats)?;
    validate_feat_order(&feat_order, feats)?;

    let actions = DecisionActions { meta_actions, thresholds, n_thresholds, feat_order, allow_refs};
    Ok(actions)
}
