use std::collections::HashSet;
use serde::Serialize;
use serde_json::Value;
use crate::features::features::TimestampedTable;
use crate::network::network::{NodePtr, Penalties, feats_penalty_from_counts};
use crate::utils::to_json_with_tag;
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

#[cfg_attr(test, automock)]
trait DecisionNetDeps {
    fn eval_branch(&self, net: &DecisionNet, branch_node: &BranchNode, feat_table: &TimestampedTable, row: usize) -> bool;
    fn eval_ref(&self, net: &DecisionNet, ref_node: &RefNode) -> bool;
    fn update_idx(&self, net: &mut DecisionNet, current_idx: usize) -> Option<usize>;
    fn ptr_abs_idx(&self, ptr: &NodePtr, len: usize) -> Option<usize>;
}

struct DecisionNetDepsImpl;
impl DecisionNetDeps for DecisionNetDepsImpl {
    fn eval_branch(&self, net: &DecisionNet, branch_node: &BranchNode, feat_table: &TimestampedTable, row: usize) -> bool {
        if let Some(feat_id) = branch_node.feat_id.as_ref() 
        && let Some(threshold) = branch_node.threshold
        && let Some(col) = feat_table.table.get(feat_id)
        && let Some(value) = col.get(row) {
            *value > threshold
        } else {
            net.default_value
        }
    }

    fn eval_ref(&self, net: &DecisionNet, ref_node: &RefNode) -> bool {
        match ref_node.ref_idx {
            None => net.default_value,
            Some(idx) => net.nodes[idx].value()
        }
    }

    fn update_idx(&self, net: &mut DecisionNet, current_idx: usize) -> Option<usize> {
        let nodes = &net.nodes;
        let next_idx = nodes[current_idx].next_idx(nodes[current_idx].value());

        if let Some(idx) = next_idx {
            net.idx_trail.push(idx);
        }

        next_idx
    }

    fn ptr_abs_idx(&self, node_ptr: &NodePtr, len: usize) -> Option<usize> {
        node_ptr.abs_idx(len)
    }
}

impl DecisionNet {
    pub fn to_json(&self) -> Value {
        to_json_with_tag(self, "type", "decision")
    }

    fn _update_idx<T>(&mut self, deps: &T, current_idx: usize) -> Option<usize> where T: DecisionNetDeps {
        deps.update_idx(self, current_idx)
    }

    fn _eval<T>(&mut self, deps: &T, feat_table: &TimestampedTable, row: usize) where T: DecisionNetDeps {
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
                DecisionNode::Branch(branch_node) => deps.eval_branch(&self, &branch_node, feat_table, row),
                DecisionNode::Ref(ref_node) => deps.eval_ref(&self, ref_node)
            };

            self.nodes[node_idx].set_value(new_value);
            current_idx = deps.update_idx(self, node_idx);
        }
    }

    fn _node_value<T>(&self, deps: &T, net: &DecisionNet, node_ptr: &NodePtr) -> bool where T: DecisionNetDeps {
        let trail_len = self.idx_trail.len();
        let maybe_idx = deps.ptr_abs_idx(node_ptr, trail_len);

        match maybe_idx {
            Some(idx) => net.nodes[net.idx_trail[idx]].value(),
            None => net.default_value
        }
    }
}



impl Network for DecisionNet {
    fn reset_state(&mut self) {
        for node in &mut self.nodes {
            node.set_value(self.default_value);
        }
    }

    fn eval(&mut self, feat_table: &TimestampedTable, row: usize) {
        self._eval(&DecisionNetDepsImpl, feat_table, row);
    }

    fn node_value(&self, node_ptr: &NodePtr) -> bool {
        self._node_value(&DecisionNetDepsImpl, self, node_ptr)
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

#[cfg_attr(test, automock)]
trait DecisionPenaltiesDeps {
    fn nodes_penalty(&self, penalties: &DecisionPenalties, net: &DecisionNet) -> f64 {
        let mut penalty = 0.0;

        for node in &net.nodes {
            penalty += penalties.node;

            match node {
                DecisionNode::Branch(_) => penalty += penalties.branch,
                DecisionNode::Ref(_) => penalty += penalties.ref_
            }
        }

        penalty
    }

    fn leaf_penalty(&self, penalties: &DecisionPenalties, out_idx: Option<usize>) -> f64 {
        match out_idx {
            None => penalties.leaf,
            Some(_) => penalties.non_leaf
        }
    }

    fn leaves_penalty(&self, penalties: &DecisionPenalties, net: &DecisionNet) -> f64 {
        penalties._leaves_penalty(&DecisionPenaltiesDepsImpl, net)
    }

    fn feats_penalty_from_counts(&self, penalties: &DecisionPenalties, n_used: usize, n_feats: usize) -> f64 {
        feats_penalty_from_counts(n_used, n_feats, penalties.used_feat, penalties.unused_feat)
    }

    fn feats_penalty(&self, penalties: &DecisionPenalties, net: &DecisionNet, n_feats: usize) -> f64 {
        penalties._feats_penalty(&DecisionPenaltiesDepsImpl, net, n_feats)
    }
}

struct DecisionPenaltiesDepsImpl;
impl DecisionPenaltiesDeps for DecisionPenaltiesDepsImpl {}

impl DecisionPenalties {
    pub fn to_json(&self) -> Value {
        to_json_with_tag(self, "type", "decision")
    }

    fn _leaves_penalty<T>(&self, deps: &T, net: &DecisionNet) -> f64 where T: DecisionPenaltiesDeps {
        let mut penalty = 0.0;

        for node in &net.nodes {
            penalty += deps.leaf_penalty(&self, node.true_idx());
            penalty += deps.leaf_penalty(&self, node.false_idx());
        }

        penalty
    }

    fn _feats_penalty<T>(&self, deps: &T, net: &DecisionNet, n_feats: usize) -> f64 where T: DecisionPenaltiesDeps {
        let mut used_feat_ids = HashSet::new();

        for node in &net.nodes {
            if let DecisionNode::Branch(branch_node) = node 
            && let Some(feat_id) = branch_node.feat_id.as_ref() {
                used_feat_ids.insert(feat_id.as_str());
            }
        }

        deps.feats_penalty_from_counts(&self, used_feat_ids.len(), n_feats)
    }

    fn _penalty<T>(&self, deps: &T, net: &DecisionNet, n_feats: usize) -> f64 where T: DecisionPenaltiesDeps {
        let mut penalty = 0.0;

        if self.node + self.branch + &self.ref_ > 0.0 {
            penalty += deps.nodes_penalty(&self, net);
        }

        if self.leaf + self.non_leaf > 0.0 {
            penalty += deps.leaves_penalty(&self, net);
        }

        if self.used_feat + self.unused_feat > 0.0 {
            penalty += deps.feats_penalty(&self, net, n_feats);
        }

        penalty
    }
}

impl Penalties<DecisionNet> for DecisionPenalties {
    fn penalty(&self, net: &DecisionNet, n_feats: usize) -> f64 {
        self._penalty(&DecisionPenaltiesDepsImpl, net, n_feats)
    }
}
