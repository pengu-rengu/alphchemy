use std::collections::HashSet;
use serde::Serialize;
use serde_json::Value;
use crate::features::features::TimestampedTable;
use crate::network::network::{Penalties, feats_penalty_from_counts};
use crate::utils::insert_tag;
use super::network::Network;
#[cfg(test)]
use mockall::automock;

#[derive(Clone, Debug, Serialize)]
pub struct BranchNode {
    pub threshold: Option<f64>,
    pub feat_id: Option<String>,
    pub true_idx: Option<usize>,
    pub false_idx: Option<usize>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Serialize)]
pub struct RefNode {
    pub ref_idx: Option<usize>,
    pub true_idx: Option<usize>,
    pub false_idx: Option<usize>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Serialize)]
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

#[derive(Clone, Debug, Serialize)]
pub struct DecisionNet {
    pub nodes: Vec<DecisionNode>,
    pub max_trail_len: usize,
    pub default_value: bool,
    #[serde(skip)]
    pub idx_trail: Vec<usize>
}

impl DecisionNet {
    pub fn to_json(&self) -> Value {
        insert_tag(self, "type", "decision")
    }

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

        let maybe_idx = node_ptr.abs_idx(trail_len);

        match maybe_idx {
            Some(idx) => {
                let node_idx = self.idx_trail[idx];
                let node = &self.nodes[node_idx];
                node.value()
            }
            None => self.default_value
        }
    }

    fn reset_state(&mut self) {
        for node in &mut self.nodes {
            node.set_value(self.default_value);
        }
    }

    fn eval(&mut self, feat_table: &TimestampedTable, row_idx: usize) {
        if self.nodes.is_empty() {
            return;
        }

        self.idx_trail.clear();
        self.idx_trail.push(0);

        let mut current_idx = Some(0);

        while let Some(node_idx) = current_idx {
            if self.idx_trail.len() >= self.max_trail_len { 
                break; 
            }

            let new_value = match &self.nodes[node_idx] {
                DecisionNode::Branch(node) => {
                    if let Some(feat_id) = node.feat_id.as_ref() && let Some(threshold) = node.threshold {
                        let maybe_val = feat_table
                            .table
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

#[derive(Clone, Copy, Debug, Serialize)]
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
    pub fn to_json(&self) -> Value {
        insert_tag(self, "type", "decision")
    }

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
