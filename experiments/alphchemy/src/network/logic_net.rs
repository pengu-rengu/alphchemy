use std::collections::HashSet;
use serde::Deserialize;
use serde_json::Value;
#[cfg(test)]
use mockall::automock;
use crate::features::features::TimestampedTable;
use crate::network::network::{Network, NodePtr, Penalties, feats_penalty_from_counts};
use crate::utils::{expect_non_neg, expect_type, parse_json, require_nullable};

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Gate { And, Or, Xor, Nand, Nor, Xnor }

#[derive(Clone, Debug, Deserialize)]
pub struct InputNode {
    #[serde(deserialize_with = "require_nullable")]
    pub threshold: Option<f64>,
    #[serde(deserialize_with = "require_nullable")]
    pub feat_id: Option<String>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Deserialize)]
pub struct GateNode {
    #[serde(deserialize_with = "require_nullable")]
    pub gate: Option<Gate>,
    #[serde(deserialize_with = "require_nullable")]
    pub in1_idx: Option<usize>,
    #[serde(deserialize_with = "require_nullable")]
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

#[cfg_attr(test, automock)]
trait LogicNetDeps {
    fn input_value(&self, net: &LogicNet, in_idx: Option<usize>) -> bool;
    fn eval_input(&self, net: &LogicNet, input_node: &InputNode, feat_table: &TimestampedTable, row: usize) -> bool;
    fn eval_gate(&self, net: &LogicNet, gate_node: &GateNode) -> bool;
    fn ptr_abs_idx(&self, ptr: &NodePtr, len: usize) -> Option<usize>;
}

struct LogicNetDepsImpl;
impl LogicNetDeps for LogicNetDepsImpl {
    fn input_value(&self, net: &LogicNet, in_idx: Option<usize>) -> bool {
        match in_idx {
            None => net.default_value,
            Some(idx) => net.nodes[idx].value()
        }
    }

    fn eval_input(&self, net: &LogicNet, input_node: &InputNode, feat_table: &TimestampedTable, row: usize) -> bool {
        if let Some(feat_id) = input_node.feat_id.as_ref()
        && let Some(threshold) = input_node.threshold
        && let Some(col) = feat_table.table.get(feat_id)
        && let Some(value) = col.get(row) {

            *value > threshold
        } else {
            net.default_value
        }
    }
    
    fn eval_gate(&self, net: &LogicNet, gate_node: &GateNode) -> bool {
        net._eval_gate(&LogicNetDepsImpl, gate_node)
    }

    fn ptr_abs_idx(&self, ptr: &NodePtr, len: usize) -> Option<usize> {
        ptr.abs_idx(len)
    }
}

impl LogicNet {

    fn _eval_gate<T>(&self, deps: &T, gate_node: &GateNode) -> bool where T: LogicNetDeps  {
        
        let value1 = deps.input_value(&self, gate_node.in1_idx);
        let value2 = deps.input_value(&self, gate_node.in2_idx);

        match gate_node.gate {
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

    fn _eval<T>(&mut self, deps: &T, feat_table: &TimestampedTable, row: usize) where T: LogicNetDeps {
        for i in 0..self.nodes.len() {

            let new_value: bool = match &self.nodes[i] {
                LogicNode::Input(input_node) => deps.eval_input(&self, input_node, feat_table, row),
                LogicNode::Gate(gate_node) => deps.eval_gate(&self, gate_node)
            };
            
            self.nodes[i].set_value(new_value);
        }
    }

    fn _node_value<T>(&self, deps: &T, node_ptr: &NodePtr)  -> bool where T: LogicNetDeps {
        let maybe_idx = deps.ptr_abs_idx(node_ptr, self.nodes.len());

        match maybe_idx {
            Some(idx) => {
                let node = &self.nodes[idx];
                node.value()
            }
            None => self.default_value
        }
    }
}


impl Network for LogicNet {

    fn reset_state(&mut self) {
        for node in &mut self.nodes {
            node.set_value(self.default_value);
        }
    }

    fn eval(&mut self, feat_table: &TimestampedTable, row: usize) {
        self._eval(&LogicNetDepsImpl, feat_table, row);
    }

    fn node_value(&self, node_ptr: &NodePtr) -> bool {
        self._node_value(&LogicNetDepsImpl, node_ptr)
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

#[cfg_attr(test, automock)]
trait LogicPenaltiesDeps {
    fn nodes_penalty(&self, penalties: &LogicPenalties, net: &LogicNet) -> f64;
    fn direction_penalty(&self, penalties: &LogicPenalties, in_idx: Option<usize>, idx: usize) -> f64;
    fn directions_penalty(&self, penalties: &LogicPenalties,  net: &LogicNet) -> f64;
    fn feats_penalty_from_counts(&self, penalties: &LogicPenalties, n_used: usize, n_feats: usize) -> f64;
    fn feats_penalty(&self, penalties: &LogicPenalties, net: &LogicNet, n_feats: usize) -> f64;
}

struct LogicPenaltiesDepsImpl;
impl LogicPenaltiesDeps for LogicPenaltiesDepsImpl {
    fn nodes_penalty(&self, penalties: &LogicPenalties, net: &LogicNet) -> f64 {
        let mut penalty = 0.0;

        for node in &net.nodes {
            penalty += penalties.node;

            match node {
                LogicNode::Input(_) => penalty += penalties.input,
                LogicNode::Gate(_) => penalty += penalties.gate
            }
        }

        penalty
    }

    fn direction_penalty(&self, penalties: &LogicPenalties, in_idx: Option<usize>, idx: usize) -> f64 {
        match in_idx {
            None => 0.0,
            Some(unwrapped_idx) => {
                if unwrapped_idx >= idx {
                    penalties.recurrence
                } else {
                    penalties.feedforward
                }
            }
        }
    }

    fn directions_penalty(&self, penalties: &LogicPenalties,  net: &LogicNet) -> f64 {
        penalties._directions_penalty(LogicPenaltiesDepsImpl, net)
    }

    fn feats_penalty_from_counts(&self, penalties: &LogicPenalties, n_used: usize, n_feats: usize) -> f64 {
        feats_penalty_from_counts(n_used, n_feats, penalties.used_feat, penalties.unused_feat)
    }

    fn feats_penalty(&self, penalties: &LogicPenalties, net: &LogicNet, n_feats: usize) -> f64 {
        penalties._feats_penalty(LogicPenaltiesDepsImpl, net, n_feats)
    }
}

impl LogicPenalties {

    fn _directions_penalty<T>(&self, deps: T, net: &LogicNet) -> f64 where T: LogicPenaltiesDeps {
        net.nodes.iter().enumerate().map(|(idx, node)| {
            let mut penalty = 0.0;

            if let LogicNode::Gate(gate_node) = node {

                penalty += deps.direction_penalty(&self, gate_node.in1_idx, idx);
                penalty += deps.direction_penalty(&self, gate_node.in2_idx, idx);
            }

            penalty
        }).sum()
    }

    fn _feats_penalty<T>(&self, deps: T, net: &LogicNet, n_feats: usize) -> f64 where T: LogicPenaltiesDeps {
        let mut used_feat_ids = HashSet::new();

        for node in &net.nodes {
            if let LogicNode::Input(input_node) = node 
            && let Some(feat_id) = input_node.feat_id.as_ref() {
                used_feat_ids.insert(feat_id.as_str());
            }
        }

        deps.feats_penalty_from_counts(&self, used_feat_ids.len(), n_feats)
    }

    fn _penalty<T>(&self, deps: T, net: &LogicNet, n_feats: usize) -> f64 where T: LogicPenaltiesDeps {
        let mut penalty = 0.0;

        if self.node + self.input + self.gate > 0.0 {
            penalty += deps.nodes_penalty(&self, net);
        }

        if self.recurrence + self.feedforward > 0.0 {
            penalty += deps.directions_penalty(&self, net);
        }

        if self.used_feat + self.unused_feat > 0.0 {
            penalty += deps.feats_penalty(&self, net, n_feats);
        }

        penalty
    }
}

impl Penalties<LogicNet> for LogicPenalties {
    fn penalty(&self, net: &LogicNet, n_feats: usize) -> f64 {
        self._penalty(LogicPenaltiesDepsImpl, net, n_feats)
    }
}

pub fn parse_logic_net(json: &Value, feat_ids: &[String]) -> Result<LogicNet, String> {
    expect_type(json, "logic", "Network")?;
    
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
    expect_type(json, "logic", "Penalties")?;

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

#[cfg(test)]
mod tests {
    use std::collections::HashMap;
    use std::vec;
    use super::*;
    use crate::test_utils::{gen_f64, gen_usize_with_max, gen_usize_with_min};
    use hegel::TestCase;
    use hegel::generators::{booleans, vecs, sampled_from};
    use mockall::predicate::{always, eq};

    #[hegel::composite]
    fn gen_input_node(tc: TestCase, draw_threshold: Option<bool>, feat_ids: Option<&[String]>, value: bool) -> InputNode {
        let threshold = if draw_threshold.unwrap_or_else(|| tc.draw(booleans())) {
            let rand_threshold = tc.draw(gen_f64());
            Some(rand_threshold)
        } else { None };
        let feat_id = feat_ids.and_then::<String, _>(|ids| {
            let rand_feat_id = tc.draw(sampled_from(ids));
            Some(rand_feat_id)
        });

        InputNode { threshold, feat_id, value }
    }

    #[hegel::composite]
    fn gen_gate_node(tc: TestCase, n_nodes: usize, draw_gate: Option<bool>, draw_in1_idx: Option<bool>, draw_in2_idx: Option<bool>, value: bool) -> GateNode {
        
        let gate = if draw_gate.unwrap_or_else(|| tc.draw(booleans())) { 
            let rand_gate = tc.draw(sampled_from(vec! [Gate::And, Gate::Or, Gate::Xor, Gate::Nand, Gate::Nor, Gate::Xnor])); 
            Some(rand_gate)
        } else { None };

        let max_idx = n_nodes - 1;
        let in1_idx = if draw_in1_idx.unwrap_or_else(|| tc.draw(booleans())) {
            let idx = tc.draw(gen_usize_with_max(max_idx));
            Some(idx)
        } else { None };
        let in2_idx = if draw_in2_idx.unwrap_or_else(|| tc.draw(booleans())) {
            let idx = tc.draw(gen_usize_with_max(max_idx));
            Some(idx)
        } else { None };

        GateNode { gate, in1_idx, in2_idx, value }
    }

    #[hegel::composite]
    fn gen_logic_net(tc: TestCase, values: &[bool]) -> LogicNet {
        let mut nodes = Vec::<LogicNode>::with_capacity(values.len());
        for value in values {
            let new_node: LogicNode;
            if tc.draw(booleans()) {
                let input_node = tc.draw(gen_input_node(None, None, *value));
                new_node = LogicNode::Input(input_node)
            } else {
                let gate_node = tc.draw(gen_gate_node(values.len(), None, None, None, *value));
                new_node = LogicNode::Gate(gate_node);
            }
            nodes.push(new_node);
        }
        LogicNet { nodes, default_value: tc.draw(booleans()) }
    }

    #[hegel::test]
    fn test_input_node(tc: TestCase) {
        let feat_ids = Some(vec!["feature".to_string()]);
        let input_node = tc.draw(gen_input_node(Some(true), feat_ids.as_deref(), false));
        
        let net = tc.draw(gen_logic_net(&Vec::<bool>::new()));
        let feat_values = tc.draw(vecs(gen_f64()).min_size(5).max_size(100));
        let row = tc.draw(gen_usize_with_max(feat_values.len() - 1));

        let feat_map = HashMap::from([
            ("feature".to_string(), feat_values.clone())
        ]);
        // TODO: max actual gen_feat_table in features.rs
        let feat_table = TimestampedTable { 
            timestamps: vec![],
            table: feat_map
        };

        let value = LogicNetDepsImpl.eval_input(&net, &input_node, &feat_table, row);
        assert_eq!(value, feat_values[row] > input_node.threshold.unwrap());

        let input_node_no_thresh = tc.draw(gen_input_node(Some(false), feat_ids.as_deref(), false));
        let no_thresh_value = LogicNetDepsImpl.eval_input(&net, &input_node_no_thresh, &feat_table, row);
        assert_eq!(no_thresh_value, net.default_value);

        let input_node_no_feat = tc.draw(gen_input_node(Some(true), None, false));
        let no_feat_value = LogicNetDepsImpl.eval_input(&net, &input_node_no_feat, &feat_table, row);
        assert_eq!(no_feat_value, net.default_value);

        let input_node_no_thresh_feat = tc.draw(gen_input_node(Some(false), None, false));
        let no_thresh_feat_value = LogicNetDepsImpl.eval_input(&net, &input_node_no_thresh_feat, &feat_table, row);
        assert_eq!(no_thresh_feat_value, net.default_value);
    }

    #[hegel::test]
    fn test_input_value(tc: TestCase) {
        let values = tc.draw(vecs(booleans()).min_size(2).max_size(25));
        let net = tc.draw(gen_logic_net(&values));

        let none_idx_value = LogicNetDepsImpl.input_value(&net, None);
        assert_eq!(none_idx_value, net.default_value);

        let idx = tc.draw(gen_usize_with_max(values.len() - 1));
        let some_idx = Some(idx);
        let some_idx_value = LogicNetDepsImpl.input_value(&net, some_idx);
        assert_eq!(some_idx_value, values[idx]);
    }

    #[hegel::test]
    fn test_gate_node(tc: TestCase) {
        let n_nodes = tc.draw(gen_usize_with_min(1));
        let mut gate_node = tc.draw(gen_gate_node(n_nodes, None, Some(true), Some(true), false));
        
        let in1_value = tc.draw(booleans());
        let in2_value;
        if gate_node.in1_idx == gate_node.in2_idx {
            in2_value = in1_value;
        } else {
            in2_value = tc.draw(booleans());
        }

        let mut mock_logic_deps = MockLogicNetDeps::new();

        let eq_in1_idx = eq(Some(gate_node.in1_idx.unwrap()));
        let input_value1_dep= mock_logic_deps.expect_input_value().with(always(), eq_in1_idx);
        input_value1_dep.returning(move |_, _| in1_value);

        let eq_in2_idx = eq(Some(gate_node.in2_idx.unwrap()));
        let input_value2_dep = mock_logic_deps.expect_input_value().with(always(), eq_in2_idx);
        input_value2_dep.returning(move |_, _| in2_value);
        
        
        
        let net = tc.draw(gen_logic_net(&Vec::<bool>::new()));

        gate_node.gate = Some(Gate::And);
        let and_value = net._eval_gate(&mock_logic_deps, &gate_node);
        assert_eq!(and_value, in1_value && in2_value);

        gate_node.gate = Some(Gate::Or);
        let or_value = net._eval_gate(&mock_logic_deps, &gate_node);
        assert_eq!(or_value, in1_value || in2_value);

        gate_node.gate = Some(Gate::Xor);
        let xor_value = net._eval_gate(&mock_logic_deps, &gate_node);
        assert_eq!(xor_value, in1_value ^ in2_value);
    }
}
