use crate::network::network::{Penalties, feats_penalty_from_used};
use super::network::Network;

#[derive(Clone, Debug)]
pub struct BranchNode {
    pub threshold: Option<f64>,
    pub feat_idx: Option<usize>,
    pub true_idx: Option<usize>,
    pub false_idx: Option<usize>,
    pub value: bool,
}

#[derive(Clone, Debug)]
pub struct RefNode {
    pub ref_idx: Option<usize>,
    pub true_idx: Option<usize>,
    pub false_idx: Option<usize>,
    pub value: bool,
}

#[derive(Clone, Debug)]
pub enum DecisionNode {
    Branch(BranchNode),
    Ref(RefNode),
}

impl DecisionNode {
    pub fn next_idx(&self, value: bool) -> Option<usize> {
        match self {
            DecisionNode::Branch(node) => if value { node.true_idx } else { node.false_idx },
            DecisionNode::Ref(node) => if value { node.true_idx } else { node.false_idx },
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
            DecisionNode::Ref(node) => node.true_idx = Some(idx),
        }
    }

    pub fn set_false_idx(&mut self, idx: usize) {
        match self {
            DecisionNode::Branch(node) => node.false_idx = Some(idx),
            DecisionNode::Ref(node) => node.false_idx = Some(idx),
        }
    }

    pub fn value(&self) -> bool {
        match self {
            DecisionNode::Branch(node) => node.value,
            DecisionNode::Ref(node) => node.value,
        }
    }

    pub fn set_value(&mut self, new_value: bool) {
        match self {
            DecisionNode::Branch(node) => node.value = new_value,
            DecisionNode::Ref(node) => node.value = new_value,
        }
    }
}

#[derive(Clone, Debug)]
pub struct DecisionNet {
    pub nodes: Vec<DecisionNode>,
    pub idx_trail: Vec<usize>,
    pub max_trail_len: usize,
    pub default_value: bool,
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
        let idx_trail = &self.idx_trail;
        let trail_len = idx_trail.len();
        
        let idx = node_ptr.abs_idx(trail_len);
        
        if let Some(node_idx) = idx_trail.get(idx) {
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
    
    fn eval(&mut self, row: &[f64]) {
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
                    if let Some(idx) = node.feat_idx && let Some(threshold) = node.threshold {
                        row[idx] > threshold
                    } else {
                        self.default_value
                    }
                }
                DecisionNode::Ref(node) => {
                    match node.ref_idx {
                        None => self.default_value,
                        Some(idx) => self.nodes[idx].value(),
                    }
                }
            };

            self.nodes[node_idx].set_value(new_value);
            current_idx = self.update_idx(node_idx);
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct DecisionPenalties {
    pub node: f64,
    pub branch: f64,
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
                DecisionNode::Ref(_) => penalty += self.ref_,
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
        let mut is_used = vec! [false; n_feats];

        for node in &net.nodes {
            if let DecisionNode::Branch(branch_node) = node && let Some(idx) = branch_node.feat_idx{
                is_used[idx] = true;
            }
        }
        
        feats_penalty_from_used(&is_used, self.used_feat, self.unused_feat)
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