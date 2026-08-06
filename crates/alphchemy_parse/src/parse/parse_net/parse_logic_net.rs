use std::collections::HashSet;

use alphchemy_engine::network::logic_net::{LogicNet, LogicNode, InputNode, GateNode, Gate, LogicPenalties};
use crate::utils::expect_non_neg;
use super::super::parse::Fields;
use super::parse_net::indexed_nodes;

#[cfg(test)]
use mockall::automock;

#[cfg_attr(test, automock)]
trait ParseLogicNetDeps {
    fn string<'a>(&self, fields: &Fields<'a>, keys: &[&'a str], default: &str) -> Result<String, String> {
        fields.string(keys, default)
    }

    fn option_string<'a>(&self, fields: &Fields<'a>, keys: &[&'a str]) -> Result<Option<String>, String> {
        fields.option_string(keys)
    }

    fn option_f64<'a>(&self, fields: &Fields<'a>, keys: &[&'a str]) -> Result<Option<f64>, String> {
        fields.option_f64(keys)
    }

    fn option_usize<'a>(&self, fields: &Fields<'a>, keys: &[&'a str]) -> Result<Option<usize>, String> {
        fields.option_usize(keys)
    }

    fn bool<'a>(&self, fields: &Fields<'a>, keys: &[&'a str], default: bool) -> Result<bool, String> {
        fields.bool(keys, default)
    }

    fn parse_gate(&self, text: &str) -> Result<Gate, String> {
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

    fn parse_option_gate<'a>(&self, fields: &Fields<'a>) -> Result<Option<Gate>, String> {
        _parse_option_gate(&ParseLogicNetDepsImpl, fields)
    }

    fn parse_logic_node<'a>(&self, fields: &Fields<'a>) -> Result<LogicNode, String> {
        _parse_logic_node(&ParseLogicNetDepsImpl, fields)
    }

    fn feat_id_set(&self, feat_ids: &[String]) -> HashSet<String> {
        feat_ids.iter().cloned().collect()
    }

    fn validate_idx(&self, idx: Option<usize>, n_nodes: usize, field: &str) -> Result<(), String> {
        super::parse_net::validate_idx(idx, n_nodes, field)
    }

    fn parse_logic_net<'a>(&self, fields: Option<Fields<'a>>, feat_ids: &[String]) -> Result<LogicNet, String> {
        _parse_logic_net(&ParseLogicNetDepsImpl, fields, feat_ids)
    }
}

trait ParseLogicNetDepsExt: ParseLogicNetDeps {
    fn child_fields<'a>(&self, fields: &Fields<'a>, keys: &[&'a str]) -> Result<Option<Fields<'a>>, String> {
        fields.child_fields(keys)
    }
}

struct ParseLogicNetDepsImpl;
impl ParseLogicNetDeps for ParseLogicNetDepsImpl {}
impl ParseLogicNetDepsExt for ParseLogicNetDepsImpl {}

#[cfg(test)]
impl ParseLogicNetDepsExt for MockParseLogicNetDeps {}

fn _parse_option_gate<T>(deps: &T, fields: &Fields) -> Result<Option<Gate>, String> where T: ParseLogicNetDeps {
    match deps.option_string(fields, &["gate"])? {
        None => Ok(None),
        Some(text) => {
            let gate = deps.parse_gate(&text)?;
            Ok(Some(gate))
        }
    }
}

fn _parse_logic_node<T>(deps: &T, fields: &Fields) -> Result<LogicNode, String> where T: ParseLogicNetDeps {
    let node_type = deps.string(fields, &["type", "net_type", "network_type"], "")?;

    match node_type.as_str() {
        "input" => {
            let threshold = deps.option_f64(fields, &["threshold"])?;
            let feat_id = deps.option_string(fields, &["feat_id"])?;
            let node = InputNode { threshold, feat_id, value: false };
            Ok(LogicNode::Input(node))
        }
        "gate" => {
            let gate = deps.parse_option_gate(fields)?;
            let in1_idx = deps.option_usize(fields, &["in1_idx"])?;
            let in2_idx = deps.option_usize(fields, &["in2_idx"])?;
            let node = GateNode { gate, in1_idx, in2_idx, value: false };
            Ok(LogicNode::Gate(node))
        }
        _ => Err(format!("invalid logic node type: {node_type}"))
    }
}

fn _parse_logic_net<T>(deps: &T, fields: Option<Fields<'_>>, feat_ids: &[String]) -> Result<LogicNet, String> where T: ParseLogicNetDepsExt {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let default_value = deps.bool(&fields, &["default_value"], false)?;
    let node_fields = deps.child_fields(&fields, &["nodes", "logic_nodes"])?;
    let nodes = indexed_nodes(node_fields, |fields| deps.parse_logic_node(fields))?;

    let unique_ids = deps.feat_id_set(feat_ids);
    let n_nodes = nodes.len();
    for node in &nodes {
        match node {
            LogicNode::Input(input) => {
                if let Some(feat_id) = input.feat_id.as_ref() && !unique_ids.contains(feat_id) {
                    return Err(format!("feat_id not found: {feat_id}"));
                }
            }
            LogicNode::Gate(gate) => {
                deps.validate_idx(gate.in1_idx, n_nodes, "in1_idx")?;
                deps.validate_idx(gate.in2_idx, n_nodes, "in2_idx")?;
            }
        }
    }

    Ok(LogicNet { nodes, default_value })
}

pub fn parse_gate(text: &str) -> Result<Gate, String> {
    ParseLogicNetDepsImpl.parse_gate(text)
}

pub fn parse_logic_net(fields: Option<Fields<'_>>, feat_ids: &[String]) -> Result<LogicNet, String> {
    ParseLogicNetDepsImpl.parse_logic_net(fields, feat_ids)
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
