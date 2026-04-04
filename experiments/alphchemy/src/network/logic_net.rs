use std::collections::HashSet;
use serde::Deserialize;
use serde_json::Value;
use crate::features::features::FeatTable;
use crate::network::network::{Network, Penalties, feats_penalty_from_counts};
use crate::utils::{parse_json, expect_non_neg};

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Gate { And, Or, Xor, Nand, Nor, Xnor }

#[derive(Clone, Debug, Deserialize)]
pub struct InputNode {
    pub threshold: Option<f64>,
    pub feat_id: Option<String>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Deserialize)]
pub struct GateNode {
    pub gate: Option<Gate>,
    pub in1_idx: Option<usize>,
    pub in2_idx: Option<usize>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum LogicNode {
    Input(InputNode),
    Gate(GateNode)
}

impl LogicNode {
    pub fn value(&self) -> bool {
        match self {
            LogicNode::Input(node) => node.value,
            LogicNode::Gate(node) => node.value
        }
    }

    pub fn set_value(&mut self, new_value: bool) {
        match self {
            LogicNode::Input(node) => node.value = new_value,
            LogicNode::Gate(node) => node.value = new_value
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct LogicNet {
    pub nodes: Vec<LogicNode>,
    pub default_value: bool
}

impl LogicNet {
    pub fn input_value(&self, in_idx: Option<usize>) -> bool {
        match in_idx {
            None => self.default_value,
            Some(idx) => self.nodes[idx].value()
        }
    }

}

impl Network for LogicNet {

    fn reset_state(&mut self) {
        for node in &mut self.nodes {
            node.set_value(self.default_value);
        }
    }

    fn eval(&mut self, feat_table: &FeatTable, row_idx: usize) {

        for i in 0..self.nodes.len() {

            let new_value = match &self.nodes[i] {
                LogicNode::Input(node) => {
                    if let Some(feat_id) = node.feat_id.as_ref()
                    && let Some(threshold) = node.threshold
                    && let Some(col) = feat_table.get(feat_id)
                    && let Some(value) = col.get(row_idx) {

                        *value > threshold
                    } else {
                        self.default_value
                    }
                }
                LogicNode::Gate(node) => {
                    let value1 = self.input_value(node.in1_idx);
                    let value2 = self.input_value(node.in2_idx);

                    match node.gate {
                        None => self.default_value,
                        Some(gate) => {
                            match gate {
                                Gate::And => value1 && value2,
                                Gate::Or => value1 || value2,
                                Gate::Xor => value1 ^ value2,
                                Gate::Nand => !(value1 && value2),
                                Gate::Nor => !(value1 || value2),
                                Gate::Xnor => !(value1 ^ value2)
                            }
                        }
                    }
                }
            };

            let node = &mut self.nodes[i];
            node.set_value(new_value);
        }
    }

    fn node_value(&self, node_ptr: &super::network::NodePtr) -> bool {
        let nodes_len = self.nodes.len();
        let idx = node_ptr.abs_idx(nodes_len);

        if let Some(node) = self.nodes.get(idx) {
            node.value()
        } else {
            self.default_value
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
pub struct LogicPenalties {
    pub node: f64,
    pub input: f64,
    pub gate: f64,
    pub recurrence: f64,
    pub feedforward: f64,
    pub used_feat: f64,
    pub unused_feat: f64
}

impl LogicPenalties {

    pub fn nodes_penalty(&self, net: &LogicNet) -> f64 {
        let mut penalty = 0.0;

        for node in &net.nodes {
            penalty += self.node;

            match node {
                LogicNode::Input(_) => penalty += self.input,
                LogicNode::Gate(_) => penalty += self.gate
            }
        }

        penalty
    }

    pub fn direction_penalty(&self, in_idx: Option<usize>, idx: usize) -> f64 {
        match in_idx {
            None => 0.0,
            Some(unwrapped_idx) => {
                if unwrapped_idx >= idx {
                    self.recurrence
                } else {
                    self.feedforward
                }
            }
        }
    }

    pub fn directions_penalty(&self, net: &LogicNet) -> f64 {
        net.nodes.iter().enumerate().map(|(idx, node)| {
            let mut penalty = 0.0;

            if let LogicNode::Gate(gate_node) = node {

                penalty += self.direction_penalty(gate_node.in1_idx, idx);
                penalty += self.direction_penalty(gate_node.in2_idx, idx);
            }

            penalty
        }).sum()
    }

    pub fn feats_penalty(&self, net: &LogicNet, n_feats: usize) -> f64 {
        let mut used_feat_ids = HashSet::new();

        for node in &net.nodes {
            if let LogicNode::Input(input_node) = node 
            && let Some(feat_id) = input_node.feat_id.as_ref() {
                used_feat_ids.insert(feat_id.as_str());
            }
        }

        feats_penalty_from_counts(used_feat_ids.len(), n_feats, self.used_feat, self.unused_feat)
    }
}

impl Penalties<LogicNet> for LogicPenalties {
    fn penalty(&self, net: &LogicNet, n_feats: usize) -> f64 {
        let mut penalty = 0.0;

        if self.node + self.input + self.gate > 0.0 {
            penalty += self.nodes_penalty(net);
        }

        if self.recurrence + self.feedforward > 0.0 {
            penalty += self.directions_penalty(net);
        }

        if self.used_feat + self.unused_feat > 0.0 {
            penalty += self.feats_penalty(net, n_feats);
        }

        penalty
    }
}
pub fn parse_logic_net(json: &Value, feat_ids: &[String]) -> Result<LogicNet, String> {
    let nodes_json = json
        .get("nodes")
        .and_then(|value| value.as_array())
        .ok_or_else(|| "missing or invalid nodes".to_string())?;

    for node_json in nodes_json {
        let node = node_json
            .as_object()
            .ok_or_else(|| "invalid node".to_string())?;
        let node_type = node
            .get("type")
            .and_then(|value| value.as_str())
            .ok_or_else(|| "missing or invalid node type".to_string())?;

        if node_type == "input" {
            if node.contains_key("feat_idx") {
                return Err("feat_idx is no longer supported; use feat_id".to_string());
            }
            if !node.contains_key("feat_id") {
                return Err("input node missing feat_id field".to_string());
            }
        }
    }

    let net = parse_json::<LogicNet>(json)?;
    let feat_ids_set = feat_ids.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();
    
    let n_nodes = net.nodes.len();
    for node in &net.nodes {
        match node {
            LogicNode::Input(input) => {
                if let Some(feat_id) = input.feat_id.as_ref() && !feat_ids_set.contains(feat_id.as_str()) {
                    return Err(format!("feat_id not found: {feat_id}"));
                }
            }
            LogicNode::Gate(gate) => {
                if let Some(idx) = gate.in1_idx && idx >= n_nodes {
                    return Err("in1_idx out of range".to_string());
                }
                if let Some(idx) = gate.in2_idx && idx >= n_nodes {
                    return Err("in2_idx out of range".to_string());
                }
            }
        }
    }

    Ok(net)
}

pub fn parse_logic_penalties(json: &Value) -> Result<LogicPenalties, String> {
    let penalties = parse_json::<LogicPenalties>(json)?;

    expect_non_neg(penalties.node, "node")?;
    expect_non_neg(penalties.input, "input")?;
    expect_non_neg(penalties.gate, "gate")?;
    expect_non_neg(penalties.recurrence, "recurrence")?;
    expect_non_neg(penalties.feedforward, "feedforward")?;
    expect_non_neg(penalties.used_feat, "used_feat")?;
    expect_non_neg(penalties.unused_feat, "unused_feat")?;

    Ok(penalties)
}
