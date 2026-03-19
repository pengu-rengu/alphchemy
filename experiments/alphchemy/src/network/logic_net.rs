use serde::Deserialize;
use serde_json::Value;
use crate::network::network::{Network, Penalties, feats_penalty_from_used};
use crate::utils::{parse_json, expect_non_neg};

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Gate { And, Or, Xor, Nand, Nor, Xnor }

#[derive(Clone, Debug, Deserialize)]
pub struct InputNode {
    pub threshold: Option<f64>,
    pub feat_idx: Option<usize>,
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

    fn eval(&mut self, row: &[f64]) {

        for i in 0..self.nodes.len() {

            let new_value = match &self.nodes[i] {
                LogicNode::Input(node) => {
                    if let Some(idx) = node.feat_idx && let Some(threshold) = node.threshold {
                        row[idx] > threshold
                    } else {
                        self.default_value
                    }
                }
                LogicNode::Gate(node) => {
                    let val1 = self.input_value(node.in1_idx);
                    let val2 = self.input_value(node.in2_idx);

                    match node.gate {
                        None => self.default_value,
                        Some(gate) => {
                            match gate {
                                Gate::And => val1 && val2,
                                Gate::Or => val1 || val2,
                                Gate::Xor => val1 ^ val2,
                                Gate::Nand => !(val1 && val2),
                                Gate::Nor => !(val1 || val2),
                                Gate::Xnor => !(val1 ^ val2)
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
        let mut is_used = vec! [false; n_feats];

        for node in &net.nodes {
            if let LogicNode::Input(input_node) = node && let Some(idx) = input_node.feat_idx {
                is_used[idx] = true;
            }
        }

        feats_penalty_from_used(&is_used, self.used_feat, self.unused_feat)
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


pub fn parse_logic_net(json: &Value, n_feats: usize) -> Result<LogicNet, String> {
    let net = parse_json::<LogicNet>(json)?;
    
    let n_nodes = net.nodes.len();
    for node in &net.nodes {
        match node {
            LogicNode::Input(input) => {
                if let Some(idx) = input.feat_idx && idx >= n_feats {
                    return Err("feat_idx out of range".to_string());
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