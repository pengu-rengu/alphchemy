use std::collections::HashSet;

use alphchemy_engine::network::logic_net::{LogicNet, LogicNode, InputNode, GateNode, Gate, LogicPenalties};
use alphchemy_engine::network::decision_net::{DecisionNet, DecisionNode, BranchNode, RefNode, DecisionPenalties};
use crate::utils::expect_non_neg;
use super::parse::Fields;

const MAX_NODES: usize = 25;
const MAX_TRAIL_LEN: usize = 25;

fn feat_id_set(feat_ids: &[String]) -> HashSet<&str> {
    feat_ids.iter().map(|feat_id| feat_id.as_str()).collect()
}

fn validate_idx(idx: Option<usize>, n_nodes: usize, field: &str) -> Result<(), String> {
    if let Some(value) = idx && value >= n_nodes {
        return Err(format!("{field} out of range"));
    }
    Ok(())
}

pub fn parse_gate(text: &str) -> Result<Gate, String> {
    match text {
        "and" | "And" | "AND" | "&&" | "&" => Ok(Gate::And),
        "or" | "Or" | "OR" | "||" | "|" => Ok(Gate::Or),
        "xor" | "Xor" | "XOR" | "^" => Ok(Gate::Xor),
        "nand" | "Nand" | "NAND" | "!&&" | "!&" => Ok(Gate::Nand),
        "nor" | "Nor" | "NOR" | "!|" | "!||" => Ok(Gate::Nor),
        "xnor" | "Xnor" | "XNOR" | "!^" => Ok(Gate::Xnor),
        _ => Err(format!("invalid gate: {text}"))
    }
}

fn parse_option_gate(fields: &Fields) -> Result<Option<Gate>, String> {
    match fields.option_string(&["gate"])? {
        None => Ok(None),
        Some(text) => {
            let gate = parse_gate(&text)?;
            Ok(Some(gate))
        }
    }
}

fn parse_logic_node(fields: &Fields) -> Result<LogicNode, String> {
    let node_type = fields.string(&["type", "net_type", "network_type"], "")?;

    match node_type.as_str() {
        "input" => {
            let threshold = fields.option_f64(&["threshold"])?;
            let feat_id = fields.option_string(&["feat_id"])?;
            let node = InputNode { threshold, feat_id, value: false };
            Ok(LogicNode::Input(node))
        }
        "gate" => {
            let gate = parse_option_gate(fields)?;
            let in1_idx = fields.option_usize(&["in1_idx"])?;
            let in2_idx = fields.option_usize(&["in2_idx"])?;
            let node = GateNode { gate, in1_idx, in2_idx, value: false };
            Ok(LogicNode::Gate(node))
        }
        _ => Err(format!("invalid logic node type: {node_type}"))
    }
}

// Place each node at the index given by its map key ("0", "1", ...), so source
// order is irrelevant. A non-numeric key, an out-of-range index, a duplicate, or
// a gap (which leaves a slot unfilled) is an explicit error.
fn indexed_nodes<T>(fields: Option<Fields<'_>>, parse_node: impl Fn(&Fields) -> Result<T, String>) -> Result<Vec<T>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut nodes = Vec::new();

    let count = fields.entries.len();

    if count > MAX_NODES { return Err(format!("Base network cannot have more than {MAX_NODES} nodes")) }

    let mut slots: Vec<Option<T>> = (0..count).map(|_| None).collect();

    for entry in &fields.entries {
        let idx = entry.key.parse::<usize>().map_err(|_| format!("invalid node index: {}", entry.key))?;

        if idx >= count {
            return Err(format!("node index {idx} out of range 0..{count}"));
        }
        if slots[idx].is_some() {
            return Err(format!("duplicate node index {idx}"));
        }

        let node_fields = Fields::from_lines(&entry.child_lines)?;
        slots[idx] = Some(parse_node(&node_fields)?);
    }

    for slot in slots {
        let node = slot.ok_or_else(|| "node indices must be contiguous from 0".to_string())?;
        nodes.push(node);
    }
    Ok(nodes)
}

pub fn parse_logic_net(fields: Option<Fields<'_>>, feat_ids: &[String]) -> Result<LogicNet, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let default_value = fields.bool(&["default_value"], false)?;
    let node_fields = fields.child_fields(&["nodes", "logic_nodes"])?;
    let nodes = indexed_nodes(node_fields, parse_logic_node)?;

    let unique_ids = feat_id_set(feat_ids);
    let n_nodes = nodes.len();
    for node in &nodes {
        match node {
            LogicNode::Input(input) => {
                if let Some(feat_id) = input.feat_id.as_ref() && !unique_ids.contains(feat_id.as_str()) {
                    return Err(format!("feat_id not found: {feat_id}"));
                }
            }
            LogicNode::Gate(gate) => {
                validate_idx(gate.in1_idx, n_nodes, "in1_idx")?;
                validate_idx(gate.in2_idx, n_nodes, "in2_idx")?;
            }
        }
    }
    
    Ok(LogicNet { nodes, default_value })
}

pub fn parse_logic_penalties(fields: Option<Fields<'_>>) -> Result<LogicPenalties, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let node = fields.f64(&["node", "node_penalty"], 0.0)?;
    let input = fields.f64(&["input", "input_penalty"], 0.0)?;
    let gate = fields.f64(&["gate", "gate_penalty"], 0.0)?;
    let recurrence = fields.f64(&["recurrence", "recurrence_penalty", "rec", "rec_penalty"], 0.0)?;
    let feedforward = fields.f64(&["feedforward", "feedforward_penalty"], 0.0)?;
    let used_feat = fields.f64(&["used_feat", "used_feat_penalty", "used_feature", "used_feature_penalty"], 0.0)?;
    let unused_feat = fields.f64(&["unused_feat", "unused_feature"], 0.0)?;

    expect_non_neg(node, "node penalty")?;
    expect_non_neg(input, "input penalty")?;
    expect_non_neg(gate, "gate penalty")?;
    expect_non_neg(recurrence, "recurrence")?;
    expect_non_neg(feedforward, "feedforward")?;
    expect_non_neg(used_feat, "used feature")?;
    expect_non_neg(unused_feat, "unused feature")?;

    let penalties = LogicPenalties {
        node, input, gate, recurrence, feedforward, used_feat, unused_feat
    };
    Ok(penalties)
}

// === Decision net parsing ===

fn parse_decision_node(fields: &Fields) -> Result<DecisionNode, String> {
    let node_type = fields.string(&["type"], "")?;

    match node_type.as_str() {
        "branch" => {
            let threshold = fields.option_f64(&["threshold", "thresh"])?;
            let feat_id = fields.option_string(&["feat_id", "feature_id"])?;
            let true_idx = fields.option_usize(&["true_idx", "true_index"])?;
            let false_idx = fields.option_usize(&["false_idx", "false_index"])?;
            let node = BranchNode { threshold, feat_id, true_idx, false_idx, value: false };
            Ok(DecisionNode::Branch(node))
        }
        "ref" => {
            let ref_idx = fields.option_usize(&["ref_idx", "ref_index", "reference_idx", "reference_index"])?;
            let true_idx = fields.option_usize(&["true_idx", "true_index"])?;
            let false_idx = fields.option_usize(&["false_idx", "false-idx", "false_index"])?;
            let node = RefNode { ref_idx, true_idx, false_idx, value: false };
            Ok(DecisionNode::Ref(node))
        }
        _ => Err(format!("invalid decision node type: {node_type}"))
    }
}

pub fn parse_decision_net(fields: Option<Fields<'_>>, feat_ids: &[String]) -> Result<DecisionNet, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let default_value = fields.bool(&["default_value", "default-value", "default"], false)?;
    let max_trail_len = fields.usize(&["max_trail_len", "max-trail-len", "max_trail_length", "max-trail-length"], 8)?;
    let node_fields = fields.child_fields(&["nodes", "decision_nodes"])?;
    let nodes = indexed_nodes(node_fields, parse_decision_node)?;

    if max_trail_len == 0 {
        return Err("max_trail_len must be > 0".to_string());
    }
    if max_trail_len > MAX_TRAIL_LEN {
        return Err(format!("max_trail_len must be <= {MAX_TRAIL_LEN}"));
    }

    let ids = feat_id_set(feat_ids);
    let n_nodes = nodes.len();
    for node in &nodes {
        match node {
            DecisionNode::Branch(branch) => {
                if let Some(feat_id) = branch.feat_id.as_ref() && !ids.contains(feat_id.as_str()) {
                    return Err(format!("feat_id not found: {feat_id}"));
                }
                validate_idx(branch.true_idx, n_nodes, "true_idx")?;
                validate_idx(branch.false_idx, n_nodes, "false_idx")?;
            }
            DecisionNode::Ref(ref_node) => {
                validate_idx(ref_node.ref_idx, n_nodes, "ref_idx")?;
                validate_idx(ref_node.true_idx, n_nodes, "true_idx")?;
                validate_idx(ref_node.false_idx, n_nodes, "false_idx")?;
            }
        }
    }

    let net = DecisionNet { nodes, max_trail_len, default_value, idx_trail: Vec::new() };
    Ok(net)
}

pub fn parse_decision_penalties(fields: Option<Fields<'_>>) -> Result<DecisionPenalties, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let node = fields.f64(&["node", "node_penalty", "node-penalty"], 0.0)?;
    let branch = fields.f64(&["branch", "branch_penalty", "branch-penalty"], 0.0)?;
    let ref_ = fields.f64(&["ref", "ref_penalty", "ref-penalty", "reference", "reference_penalty", "reference-penalty"], 0.0)?;
    let leaf = fields.f64(&["leaf"], 0.0)?;
    let non_leaf = fields.f64(&["non_leaf"], 0.0)?;
    let used_feat = fields.f64(&["used_feat"], 0.0)?;
    let unused_feat = fields.f64(&["unused_feat"], 0.0)?;

    expect_non_neg(node, "node")?;
    expect_non_neg(branch, "branch")?;
    expect_non_neg(ref_, "ref")?;
    expect_non_neg(leaf, "leaf")?;
    expect_non_neg(non_leaf, "non_leaf")?;
    expect_non_neg(used_feat, "used_feat")?;
    expect_non_neg(unused_feat, "unused_feat")?;

    let penalties = DecisionPenalties {
        node, branch, ref_, leaf, non_leaf, used_feat, unused_feat
    };
    Ok(penalties)
}
