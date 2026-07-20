use std::collections::{HashMap, HashSet};

use alphchemy_engine::features::features::{Feature, BBOutput, DCOutput, feat_ids};
use alphchemy_engine::actions::actions::{Action, ThresholdRange};
use alphchemy_engine::actions::logic_actions::LogicActions;
use alphchemy_engine::actions::decision_actions::DecisionActions;
use alphchemy_engine::network::logic_net::Gate;
use super::parse::Fields;
use super::parse_net::parse_gate;

const MAX_SUBACTIONS: usize = 5;
const MAX_META_ACTIONS: usize = 25;
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

fn parse_sub_actions(texts: &[String]) -> Result<Vec<Action>, String> {
    let n_sub_actions = texts.len();

    if n_sub_actions > MAX_SUBACTIONS { return Err(format!("Meta actions cannot have more than {MAX_SUBACTIONS} sub actions")) }

    let mut actions = Vec::with_capacity(n_sub_actions);

    for text in texts {
        let action = parse_action(text, None)?;
        actions.push(action);
    }

    Ok(actions)
}

// === Shared section parsing ===

fn parse_meta_actions(fields: Option<Fields<'_>>) -> Result<HashMap<String, Vec<Action>>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut meta_actions = HashMap::new();

    for entry in &fields.entries {
        if parse_action(entry.key, None).is_ok() {
            return Err(format!("meta action label conflicts with built-in action: {}", entry.key));
        }

        let sub_fields = Fields::from_lines(&entry.child_lines)?;
        let sub_action_texts = sub_fields.string_list(&["sub_actions"], Vec::new())?;
        let sub_actions = parse_sub_actions(&sub_action_texts)?;
        meta_actions.insert(entry.key.to_string(), sub_actions);
    }

    if meta_actions.len() > MAX_META_ACTIONS { return Err(format!("Cannot have more than {MAX_META_ACTIONS} meta actions")) }

    Ok(meta_actions)
}

fn default_threshold_range(feat: &Feature) -> ThresholdRange {
    match feat {
        Feature::Constant(feat) => {
            let min = feat.constant - 0.5;
            let max = feat.constant + 0.5;
            ThresholdRange { min, max }
        }
        Feature::RawReturns(_) => ThresholdRange { min: -0.1, max: 0.1 },
        Feature::NormalizedSMA(_) | Feature::NormalizedEMA(_) => ThresholdRange { min: 0.9, max: 1.1 },
        Feature::NormalizedMACD(_) => ThresholdRange { min: -0.1, max: 0.1 },
        Feature::RSI(_) | Feature::Stochastic(_) => ThresholdRange { min: 0.0, max: 100.0 },
        Feature::NormalizedBB(feat) => match feat.output {
            BBOutput::Upper | BBOutput::Lower => ThresholdRange { min: 0.9, max: 1.1 },
            BBOutput::Width => ThresholdRange { min: 0.0, max: 0.2 }
        },
        Feature::NormalizedATR(_) => ThresholdRange { min: 0.0, max: 0.1 },
        Feature::ROC(_) => ThresholdRange { min: 0.9, max: 1.1 },
        Feature::NormalizedDC(feat) => match feat.output {
            DCOutput::Upper | DCOutput::Lower | DCOutput::Middle => ThresholdRange { min: 0.9, max: 1.1 },
            DCOutput::Width => ThresholdRange { min: 0.0, max: 0.2 }
        }
    }
}

fn parse_thresholds(fields: Option<Fields<'_>>, feats: &[Feature]) -> Result<HashMap<String, ThresholdRange>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut thresholds = HashMap::new();

    for feat in feats {
        let feat_id = feat.id();
        let threshold_range = default_threshold_range(feat);
        thresholds.insert(feat_id, threshold_range);
    }

    let mut threshold_ids = HashSet::new();

    for entry in &fields.entries {
        if !threshold_ids.insert(entry.key) {
            return Err(format!("duplicate threshold for feature id \"{}\"", entry.key));
        }
    }

    for entry in &fields.entries {
        let feat_id = entry.key.to_string();

        let maybe_default_range = thresholds.get(&feat_id);
        let default_range = maybe_default_range.ok_or(format!("feature with id \"{feat_id}\" not found"))?;
        let range_fields = Fields::from_lines(&entry.child_lines)?;
        let min = range_fields.f64(&["min", "minimum"], default_range.min)?;
        let max = range_fields.f64(&["max", "maximum"], default_range.max)?;

        let range = ThresholdRange { min, max };
        thresholds.insert(feat_id, range);
    }

    Ok(thresholds)
}

fn parse_gates(texts: &[String]) -> Result<Vec<Gate>, String> {
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

struct ActionsShared {
    meta_actions: HashMap<String, Vec<Action>>,
    thresholds: HashMap<String, ThresholdRange>,
    n_thresholds: usize,
    feat_order: Vec<String>
}

fn parse_actions_shared(fields: &Fields, feats: &[Feature], expected_type: &str) -> Result<ActionsShared, String> {
    let action_type = fields.string(&["type", "actions_type"], expected_type)?;
    if action_type != expected_type {
        return Err(format!("invalid actions type: {action_type}"));
    }

    let meta_fields = fields.child_fields(&["meta_actions", "grouped_actions"])?;
    let meta_actions = parse_meta_actions(meta_fields)?;

    let threshold_fields = fields.child_fields(&["thresholds", "thresholds_grid"])?;
    let thresholds = parse_thresholds(threshold_fields, feats)?;

    let n_thresholds = fields.usize(&["n_thresholds"], 5)?;
    let default_feat_order = feat_ids(feats);
    let feat_order = fields.string_list(&["feat_order"], default_feat_order)?;

    if n_thresholds == 0 {
        return Err("n_thresholds must be > 0".to_string());
    }
    validate_thresholds(&thresholds, feats)?;
    validate_feat_order(&feat_order, feats)?;

    Ok(ActionsShared { meta_actions, thresholds, n_thresholds, feat_order })
}

pub fn parse_logic_actions(fields: Option<Fields<'_>>, feats: &[Feature]) -> Result<LogicActions, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let shared = parse_actions_shared(&fields, feats, "logic")?;
    let allow_recurrence = fields.bool(&["allow_recurrence", "allow_rec", "allow_recurrent_nodes"], false)?;
    let gate_texts = fields.string_list(&["allowed_gates"], vec!["and".to_string(), "or".to_string(), "xor".to_string()])?;
    let allowed_gates = parse_gates(&gate_texts)?;

    let actions = LogicActions {
        meta_actions: shared.meta_actions,
        thresholds: shared.thresholds,
        n_thresholds: shared.n_thresholds,
        feat_order: shared.feat_order,
        allow_recurrence,
        allowed_gates
    };
    Ok(actions)
}

pub fn parse_decision_actions(fields: Option<Fields<'_>>, feats: &[Feature]) -> Result<DecisionActions, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let shared = parse_actions_shared(&fields, feats, "decision")?;
    let allow_refs = fields.bool(&["allow_refs", "allow_ref_nodes", "allow_references", "allow_reference_nodes"], false)?;

    let actions = DecisionActions {
        meta_actions: shared.meta_actions,
        thresholds: shared.thresholds,
        n_thresholds: shared.n_thresholds,
        feat_order: shared.feat_order,
        allow_refs
    };
    Ok(actions)
}
