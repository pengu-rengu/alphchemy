use std::collections::HashSet;
use serde::Deserialize;
use serde_json::Value;
use crate::features::features::FeatTable;
use crate::network::network::{Penalties, feats_penalty_from_counts};
use crate::utils::{parse_json, expect_non_neg};
use super::network::Network;

#[derive(Clone, Debug, Deserialize)]
pub struct BranchNode {
    pub threshold: Option<f64>,
    pub feat_id: Option<String>,
    pub true_idx: Option<usize>,
    pub false_idx: Option<usize>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Deserialize)]
pub struct RefNode {
    pub ref_idx: Option<usize>,
    pub true_idx: Option<usize>,
    pub false_idx: Option<usize>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum DecisionNode {
    Branch(BranchNode),
    Ref(RefNode)
}

impl DecisionNode {
    pub fn next_idx(&self, value: bool) -> Option<usize> {
        match self {
            DecisionNode::Branch(node) => if value { node.true_idx } else { node.false_idx },
            DecisionNode::Ref(node) => if value { node.true_idx } else { node.false_idx }
        }
    }

    pub fn true_idx(&self) -> Option<usize> {
        match self {
            DecisionNode::Branch(node) => node.true_idx,
            DecisionNode::Ref(node) => node.true_idx
        }
    }

    pub fn false_idx(&self) -> Option<usize> {
        match self {
            DecisionNode::Branch(node) => node.false_idx,
            DecisionNode::Ref(node) => node.false_idx
        }
    }

    pub fn set_true_idx(&mut self, idx: usize) {
        match self {
            DecisionNode::Branch(node) => node.true_idx = Some(idx),
            DecisionNode::Ref(node) => node.true_idx = Some(idx)
        }
    }

    pub fn set_false_idx(&mut self, idx: usize) {
        match self {
            DecisionNode::Branch(node) => node.false_idx = Some(idx),
            DecisionNode::Ref(node) => node.false_idx = Some(idx)
        }
    }

    pub fn value(&self) -> bool {
        match self {
            DecisionNode::Branch(node) => node.value,
            DecisionNode::Ref(node) => node.value
        }
    }

    pub fn set_value(&mut self, new_value: bool) {
        match self {
            DecisionNode::Branch(node) => node.value = new_value,
            DecisionNode::Ref(node) => node.value = new_value
        }
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct DecisionNet {
    pub nodes: Vec<DecisionNode>,
    pub max_trail_len: usize,
    pub default_value: bool,
    #[serde(skip)]
    pub idx_trail: Vec<usize>
}

impl DecisionNet {
    pub fn update_idx(&mut self, current_idx: usize) -> Option<usize> {
        let node_value = self.nodes[current_idx].value();
        let next_idx = self.nodes[current_idx].next_idx(node_value);

        if let Some(idx) = next_idx {
            self.idx_trail.push(idx);
        }

        next_idx
    }
}

impl Network for DecisionNet {
    fn node_value(&self, node_ptr: &super::network::NodePtr) -> bool {
        let trail_len = self.idx_trail.len();

        let idx = node_ptr.abs_idx(trail_len);

        if let Some(node_idx) = self.idx_trail.get(idx) {
            self.nodes[*node_idx].value()
        } else {
            self.default_value
        }
    }

    fn reset_state(&mut self) {
        for node in &mut self.nodes {
            node.set_value(self.default_value);
        }
    }

    fn eval(&mut self, feat_table: &FeatTable, row_idx: usize) {
        if self.nodes.is_empty() {
            return;
        }

        self.idx_trail.clear();
        self.idx_trail.push(0);

        let mut current_idx = Some(0);

        while let Some(node_idx) = current_idx {
            if self.idx_trail.len() >= self.max_trail_len { break; }

            let new_value = match &self.nodes[node_idx] {
                DecisionNode::Branch(node) => {
                    if let Some(feat_id) = node.feat_id.as_ref() && let Some(threshold) = node.threshold {
                        let maybe_val = feat_table
                            .get(feat_id)
                            .and_then(|values| values.get(row_idx));
                        maybe_val.map_or(self.default_value, |&value| value > threshold)
                    } else {
                        self.default_value
                    }
                }
                DecisionNode::Ref(node) => {
                    match node.ref_idx {
                        None => self.default_value,
                        Some(idx) => self.nodes[idx].value()
                    }
                }
            };

            self.nodes[node_idx].set_value(new_value);
            current_idx = self.update_idx(node_idx);
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
pub struct DecisionPenalties {
    pub node: f64,
    pub branch: f64,
    #[serde(rename = "ref")]
    pub ref_: f64,
    pub leaf: f64,
    pub non_leaf: f64,
    pub used_feat: f64,
    pub unused_feat: f64
}

impl DecisionPenalties {
    pub fn nodes_penalty(&self, net: &DecisionNet) -> f64 {
        let mut penalty = 0.0;

        for node in &net.nodes {
            penalty += self.node;

            match node {
                DecisionNode::Branch(_) => penalty += self.branch,
                DecisionNode::Ref(_) => penalty += self.ref_
            }
        }

        penalty
    }

    pub fn leaf_penalty(&self, out_idx: Option<usize>) -> f64 {
        match out_idx {
            None => self.leaf,
            Some(_) => self.non_leaf
        }
    }

    pub fn leaves_penalty(&self, net: &DecisionNet) -> f64 {
        let mut penalty = 0.0;

        for node in &net.nodes {
            penalty += self.leaf_penalty(node.true_idx());
            penalty += self.leaf_penalty(node.false_idx());
        }

        penalty
    }

    pub fn feats_penalty(&self, net: &DecisionNet, n_feats: usize) -> f64 {
        let mut used_feat_ids = HashSet::new();

        for node in &net.nodes {
            if let DecisionNode::Branch(branch_node) = node 
            && let Some(feat_id) = branch_node.feat_id.as_ref() {
                used_feat_ids.insert(feat_id.as_str());
            }
        }

        feats_penalty_from_counts(used_feat_ids.len(), n_feats, self.used_feat, self.unused_feat)
    }
}

impl Penalties<DecisionNet> for DecisionPenalties {
    fn penalty(&self, net: &DecisionNet, n_feats: usize) -> f64 {
        let mut penalty = 0.0;

        if self.node + self.branch + self.ref_ > 0.0 {
            penalty += self.nodes_penalty(net);
        }

        if self.leaf + self.non_leaf > 0.0 {
            penalty += self.leaves_penalty(net);
        }

        if self.used_feat + self.unused_feat > 0.0 {
            penalty += self.feats_penalty(net, n_feats);
        }

        penalty
    }
}
pub fn parse_decision_net(json: &Value, feat_ids: &[String]) -> Result<DecisionNet, String> {
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

        if node_type == "branch" {
            if node.contains_key("feat_idx") {
                return Err("feat_idx is no longer supported; use feat_id".to_string());
            }
            if !node.contains_key("feat_id") {
                return Err("branch node missing feat_id field".to_string());
            }
        }
    }

    let net = parse_json::<DecisionNet>(json)?;
    let feat_ids_set = feat_ids.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();

    if net.max_trail_len == 0 {
        return Err("max_trail_len must be > 0".to_string());
    }

    let n_nodes = net.nodes.len();
    for node in &net.nodes {
        match node {
            DecisionNode::Branch(branch) => {
                if let Some(feat_id) = branch.feat_id.as_ref() && !feat_ids_set.contains(feat_id.as_str()) {
                    return Err(format!("feat_id not found: {feat_id}"));
                }
                if let Some(idx) = branch.true_idx && idx >= n_nodes {
                    return Err("true_idx out of range".to_string());
                }
                if let Some(idx) = branch.false_idx && idx >= n_nodes {
                    return Err("false_idx out of range".to_string());
                }
            }
            DecisionNode::Ref(ref_node) => {
                if let Some(idx) = ref_node.ref_idx && idx >= n_nodes {
                    return Err("ref_idx out of range".to_string());
                }
                if let Some(idx) = ref_node.true_idx && idx >= n_nodes {
                    return Err("true_idx out of range".to_string());
                }
                if let Some(idx) = ref_node.false_idx && idx >= n_nodes {
                    return Err("false_idx out of range".to_string());
                }
            }
        }
    }

    Ok(net)
}

pub fn parse_decision_penalties(json: &Value) -> Result<DecisionPenalties, String> {
    let penalties = parse_json::<DecisionPenalties>(json)?;

    expect_non_neg(penalties.node, "node")?;
    expect_non_neg(penalties.branch, "branch")?;
    expect_non_neg(penalties.ref_, "ref")?;
    expect_non_neg(penalties.leaf, "leaf")?;
    expect_non_neg(penalties.non_leaf, "non_leaf")?;
    expect_non_neg(penalties.used_feat, "used_feat")?;
    expect_non_neg(penalties.unused_feat, "unused_feat")?;

    Ok(penalties)
}
