use alphchemy_engine::network::logic_net::{LogicNet, LogicNode, InputNode, GateNode, Gate, LogicPenalties};
use crate::utils::expect_non_neg;
use super::super::parse::Fields;
use super::parse_net::{feat_id_set, validate_idx, indexed_nodes};

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
