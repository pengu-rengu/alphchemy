use std::collections::HashSet;
use serde::Serialize;
use serde_json::Value;
use crate::features::features::TimestampedTable;
use crate::network::network::{NodePtr, Penalties, feats_penalty_from_counts};
use crate::utils::to_json_with_tag;
use super::network::Network;
#[cfg(test)]
use mockall::automock;

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct BranchNode {
    pub threshold: Option<f64>,
    pub feat_id: Option<String>,
    pub true_idx: Option<usize>,
    pub false_idx: Option<usize>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct RefNode {
    pub ref_idx: Option<usize>,
    pub true_idx: Option<usize>,
    pub false_idx: Option<usize>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Serialize, PartialEq)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum DecisionNode {
    Branch(BranchNode),
    Ref(RefNode)
}

impl DecisionNode {

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

    fn next_idx(&self, node: &DecisionNode) -> Option<usize> {
        if node.value() { node.true_idx() } else { node.false_idx() }
    }

    fn update_idx(&self, net: &mut DecisionNet, current_idx: usize) -> Option<usize> {
        net._update_idx(&DecisionNetDepsImpl, current_idx)
    }

    fn ptr_abs_idx(&self, node_ptr: &NodePtr, len: usize) -> Option<usize> {
        node_ptr.abs_idx(len)
    }
}

struct DecisionNetDepsImpl;
impl DecisionNetDeps for DecisionNetDepsImpl {}

impl DecisionNet {
    fn _update_idx<T>(&mut self, deps: &T, current_idx: usize) -> Option<usize> where T: DecisionNetDeps {
        let next_idx = deps.next_idx(&self.nodes[current_idx]);

        if let Some(idx) = next_idx {
            self.idx_trail.push(idx);
        }

        next_idx
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
                DecisionNode::Branch(branch_node) => deps.eval_branch(self, branch_node, feat_table, row),
                DecisionNode::Ref(ref_node) => deps.eval_ref(self, ref_node)
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
    fn to_json(&self) -> Value {
        to_json_with_tag(self, "type", "decision")
    }

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
    fn _leaves_penalty<T>(&self, deps: &T, net: &DecisionNet) -> f64 where T: DecisionPenaltiesDeps {
        let mut penalty = 0.0;

        for node in &net.nodes {
            penalty += deps.leaf_penalty(self, node.true_idx());
            penalty += deps.leaf_penalty(self, node.false_idx());
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

        deps.feats_penalty_from_counts(self, used_feat_ids.len(), n_feats)
    }

    fn _penalty<T>(&self, deps: &T, net: &DecisionNet, n_feats: usize) -> f64 where T: DecisionPenaltiesDeps {
        let mut penalty = 0.0;

        if self.node + self.branch + self.ref_ > 0.0 {
            penalty += deps.nodes_penalty(self, net);
        }

        if self.leaf + self.non_leaf > 0.0 {
            penalty += deps.leaves_penalty(self, net);
        }

        if self.used_feat + self.unused_feat > 0.0 {
            penalty += deps.feats_penalty(self, net, n_feats);
        }

        penalty
    }
}

impl Penalties<DecisionNet> for DecisionPenalties {
    fn to_json(&self) -> Value {
        to_json_with_tag(self, "type", "decision")
    }

    fn penalty(&self, net: &DecisionNet, n_feats: usize) -> f64 {
        self._penalty(&DecisionPenaltiesDepsImpl, net, n_feats)
    }
}


#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;
    use std::collections::HashSet;
    use std::rc::Rc;
    use crate::{
        features::features::tests::gen_feat_table,
        network::network::tests::gen_node_ptr,
        test_utils::{gen_f64, gen_text, gen_usize, gen_usize_with_max, gen_usize_with_min, gen_vec}
    };
    use approx::assert_relative_eq;
    use hegel::{TestCase,
        generators::{booleans, sampled_from}
    };
    use mockall::predicate::{always, eq, in_hash};

    #[hegel::composite]
    fn gen_branch_node(tc: TestCase, n_nodes: usize, draw_threshold: Option<bool>, feat_ids: Option<&[String]>, draw_feat_id: Option<bool>, draw_true_idx: Option<bool>, draw_false_idx: Option<bool>) -> BranchNode {
        let threshold = if draw_threshold.unwrap_or_else(|| tc.draw(booleans())) {
            Some(tc.draw(gen_f64()))
        } else { None };

        let feat_id = if draw_feat_id.unwrap_or_else(|| tc.draw(booleans())) {
            let ids = match feat_ids {
                Some(ids) => ids,
                None => {
                    let n_feats = tc.draw(gen_usize_with_max(9)) + 1;
                    &tc.draw(gen_vec(gen_text(), n_feats))
                }
            };

            Some(tc.draw(sampled_from(ids)))
        } else { None };

        let max_idx = n_nodes - 1;
        let true_idx = if draw_true_idx.unwrap_or_else(|| tc.draw(booleans())) {
            Some(tc.draw(gen_usize_with_max(max_idx)))
        } else { None };

        let false_idx = if draw_false_idx.unwrap_or_else(|| tc.draw(booleans())) {
            Some(tc.draw(gen_usize_with_max(max_idx)))
        } else { None };

        BranchNode { threshold, feat_id, true_idx, false_idx, value: tc.draw(booleans()) }
    }

    #[hegel::composite]
    fn gen_ref_node(tc: TestCase, n_nodes: usize, draw_ref_idx: Option<bool>, draw_true_idx: Option<bool>, draw_false_idx: Option<bool>) -> RefNode {
        let max_idx = n_nodes - 1;
        let ref_idx = if draw_ref_idx.unwrap_or_else(|| tc.draw(booleans())) {
            Some(tc.draw(gen_usize_with_max(max_idx)))
        } else { None };

        let true_idx = if draw_true_idx.unwrap_or_else(|| tc.draw(booleans())) {
            Some(tc.draw(gen_usize_with_max(max_idx)))
        } else { None };

        let false_idx = if draw_false_idx.unwrap_or_else(|| tc.draw(booleans())) {
            Some(tc.draw(gen_usize_with_max(max_idx)))
        } else { None };

        RefNode { ref_idx, true_idx, false_idx, value: tc.draw(booleans()) }
    }

    #[hegel::composite]
    fn gen_decision_net(tc: TestCase, empty_nodes: Option<bool>, feat_ids: Option<&[String]>, empty_trail: Option<bool>) -> DecisionNet {
        let n_nodes = if empty_nodes.unwrap_or_else(|| tc.draw(booleans())) { 0 } else {
            tc.draw(gen_usize_with_min(1))
        };
        let nodes = (0..n_nodes).map(|_| {
            if tc.draw(booleans()) {
                let branch_node = tc.draw(gen_branch_node(n_nodes, None, feat_ids, None, None, None));
                DecisionNode::Branch(branch_node)
            } else {
                let ref_node = tc.draw(gen_ref_node(n_nodes, None, None, None));
                DecisionNode::Ref(ref_node)
            }
        }).collect();

        let max_trail_len = tc.draw(gen_usize_with_min(1));
        let idx_trail = if n_nodes > 0 {
            let trail_len = if empty_trail.unwrap_or_else(|| tc.draw(booleans())) { 0 } else {
                tc.draw(gen_usize_with_max(max_trail_len - 1)) + 1
            };
            let idx_gen = gen_usize_with_max(n_nodes - 1);
            tc.draw(gen_vec(idx_gen, trail_len))
        } else { Vec::new() };

        DecisionNet {
            nodes,
            max_trail_len,
            default_value: tc.draw(booleans()),
            idx_trail
        }

    }

    #[hegel::composite]
    fn gen_decision_penalties(tc: TestCase) -> DecisionPenalties {
        let node = tc.draw(gen_f64());
        let branch = tc.draw(gen_f64());
        let ref_ = tc.draw(gen_f64());
        let leaf = tc.draw(gen_f64());
        let non_leaf = tc.draw(gen_f64());
        let used_feat = tc.draw(gen_f64());
        let unused_feat = tc.draw(gen_f64());

        DecisionPenalties { node, branch, ref_, leaf, non_leaf, used_feat, unused_feat }
    }

    #[hegel::test]
    fn test_branch_node(tc: TestCase) {
        let feat_table = tc.draw(gen_feat_table());
        let feat_key_idx = tc.draw(gen_usize_with_max(feat_table.table.len() - 1));
        let feat_id = feat_table.table.keys().nth(feat_key_idx).unwrap();
        let feat_ids = Some(vec![feat_id.to_string()]);
        let feat_values = &feat_table.table[feat_id];
        let row = tc.draw(gen_usize_with_max(feat_values.len() - 1));

        let net  = tc.draw(gen_decision_net(Some(false), None, None));
        let n_nodes = net.nodes.len();
        let default_value = net.default_value;

        let branch_node = tc.draw(gen_branch_node(n_nodes, Some(true), feat_ids.as_deref(), Some(true), None, None));
        let value = DecisionNetDepsImpl.eval_branch(&net, &branch_node, &feat_table, row);
        assert_eq!(value, feat_values[row] > branch_node.threshold.unwrap());

        let branch_node_no_thresh = tc.draw(gen_branch_node(n_nodes, Some(false), feat_ids.as_deref(), Some(true), None, None));
        let no_thresh_value = DecisionNetDepsImpl.eval_branch(&net, &branch_node_no_thresh, &feat_table, row);
        assert_eq!(no_thresh_value, default_value);

        let branch_node_no_feat = tc.draw(gen_branch_node(n_nodes, Some(true), None, Some(false), None, None));
        let no_feat_value = DecisionNetDepsImpl.eval_branch(&net, &branch_node_no_feat, &feat_table, row);
        assert_eq!(no_feat_value, default_value);

        let branch_node_no_thresh_feat = tc.draw(gen_branch_node(n_nodes, Some(false), None, None, None, None));
        let no_thresh_feat_value = DecisionNetDepsImpl.eval_branch(&net, &branch_node_no_thresh_feat, &feat_table, row);
        assert_eq!(no_thresh_feat_value, default_value);
    }

    #[hegel::test]
    fn test_ref_node(tc: TestCase) {
        let net = tc.draw(gen_decision_net(Some(false), None, None));
        let n_nodes = net.nodes.len();

        let ref_node = tc.draw(gen_ref_node(n_nodes, Some(true), None, None));
        let value = DecisionNetDepsImpl.eval_ref(&net, &ref_node);
        assert_eq!(value, net.nodes[ref_node.ref_idx.unwrap()].value());

        let ref_node_no_idx = tc.draw(gen_ref_node(n_nodes, Some(false), None, None));
        let no_idx_value = DecisionNetDepsImpl.eval_ref(&net, &ref_node_no_idx);
        assert_eq!(no_idx_value, net.default_value);
    }

    #[hegel::test]
    fn test_next_idx(tc: TestCase) {
        let net = tc.draw(gen_decision_net(Some(false), None, None));
        let n_nodes = net.nodes.len();

        let branch_node = tc.draw(gen_branch_node(n_nodes, None, None, None, None, Some(false)));
        let node = DecisionNode::Branch(branch_node.clone());
        assert_eq!(DecisionNetDepsImpl.next_idx(&node), if branch_node.value { branch_node.true_idx } else { None });

        let branch_node = tc.draw(gen_branch_node(n_nodes, None, None, None, Some(false), None));
        let node = DecisionNode::Branch(branch_node.clone());
        assert_eq!(DecisionNetDepsImpl.next_idx(&node), if branch_node.value { None } else { branch_node.false_idx });
    }

    #[hegel::test]
    fn test_update_idx(tc: TestCase) {
        let mut net = tc.draw(gen_decision_net(Some(false), None, Some(true)));

        let mut mock_deps = MockDecisionNetDeps::new();

        let current_idx = tc.draw(gen_usize_with_max(net.nodes.len() - 1));
        let eq_node = eq(net.nodes[current_idx].clone());
        let expected_next_idx = tc.draw(gen_usize());

        let next_idx_dep = mock_deps.expect_next_idx().times(1);
        let next_idx_dep = next_idx_dep.with(eq_node);

        next_idx_dep.return_const(expected_next_idx);

        let next_idx = net._update_idx(&mock_deps, current_idx);

        assert_eq!(next_idx, Some(expected_next_idx));
        assert_eq!(net.idx_trail, vec![expected_next_idx]);
    }

    #[hegel::test]
    fn test_net_eval(tc: TestCase) {
        let feat_table = tc.draw(gen_feat_table());
        let mut net = tc.draw(gen_decision_net(Some(false), None, None));
        let n_nodes = net.nodes.len();
        net.max_trail_len = n_nodes + 1;

        let mut n_branch_nodes = 0;
        let mut n_ref_nodes = 0;
        for node in &net.nodes {
            match node {
                DecisionNode::Branch(_) => n_branch_nodes += 1,
                DecisionNode::Ref(_) => n_ref_nodes += 1
            }
        }

        let mut mock_deps = MockDecisionNetDeps::new();

        let expected_values = Rc::new(tc.draw(gen_vec(booleans(), n_nodes)));
        let value_idx = Rc::new(Cell::new(0));

        let eval_branch_dep = mock_deps.expect_eval_branch().times(n_branch_nodes);
        let eval_branch_dep = eval_branch_dep.with(always(), always(), always(), always());

        let value_idx_branch = Rc::clone(&value_idx);
        let expected_values_branch = Rc::clone(&expected_values);
        eval_branch_dep.returning_st(move |_, _, _, _| {
            let idx = value_idx_branch.get();
            let value = expected_values_branch[idx];
            value_idx_branch.set(idx + 1);
            value
        });

        let eval_ref_dep = mock_deps.expect_eval_ref().times(n_ref_nodes);
        let eval_ref_dep = eval_ref_dep.with(always(), always());

        let value_idx_ref = Rc::clone(&value_idx);
        let expected_values_ref = Rc::clone(&expected_values);
        eval_ref_dep.returning_st(move |_, _| {
            let idx = value_idx_ref.get();
            let value = expected_values_ref[idx];
            value_idx_ref.set(idx + 1);
            value
        });

        let update_idx_dep = mock_deps.expect_update_idx().times(n_nodes);
        let update_idx_dep = update_idx_dep.with(always(), always());
        update_idx_dep.returning_st(|net, current_idx| {
            let next_idx = current_idx + 1;
            if next_idx < net.nodes.len() {
                net.idx_trail.push(next_idx);
                Some(next_idx)
            } else {
                None
            }
        });
        
        net._eval(&mock_deps, &feat_table, 0);

        assert_eq!(value_idx.get(), n_nodes);
        for idx in 0..net.nodes.len() {
            assert_eq!(net.nodes[idx].value(), expected_values[idx]);
        }
    }

    #[hegel::test]
    fn test_node_value(tc: TestCase) {
        let net = tc.draw(gen_decision_net(Some(false), None, Some(false)));
        let trail_len = net.idx_trail.len();
        let node_ptr = tc.draw(gen_node_ptr(trail_len, None));
        let expected_trail_idx = tc.draw(gen_usize_with_max(trail_len - 1));

        let mut mock_deps = MockDecisionNetDeps::new();

        let eq_node_ptr = eq(node_ptr.clone());
        let eq_trail_len = eq(trail_len);

        let ptr_abs_idx_dep = mock_deps.expect_ptr_abs_idx().times(1);
        let ptr_abs_idx_dep = ptr_abs_idx_dep.with(eq_node_ptr.clone(), eq_trail_len);
        ptr_abs_idx_dep.return_const_st(Some(expected_trail_idx));

        let some_idx_value = net._node_value(&mock_deps, &net, &node_ptr);

        let mut mock_deps = MockDecisionNetDeps::new();

        let ptr_abs_idx_dep = mock_deps.expect_ptr_abs_idx().times(1);
        let ptr_abs_idx_dep = ptr_abs_idx_dep.with(eq_node_ptr, eq_trail_len);
        ptr_abs_idx_dep.return_const_st(None);

        let none_idx_value = net._node_value(&mock_deps, &net, &node_ptr);

        assert_eq!(some_idx_value, net.nodes[net.idx_trail[expected_trail_idx]].value());
        assert_eq!(none_idx_value, net.default_value);
    }

    #[hegel::test]
    fn test_nodes_penalty(tc: TestCase) {
        let penalties = tc.draw(gen_decision_penalties());
        let net = tc.draw(gen_decision_net(None, None, None));

        let mut expected_penalty = 0.0;
        for node in &net.nodes {
            expected_penalty += penalties.node;
            match node {
                DecisionNode::Branch(_) => expected_penalty += penalties.branch,
                DecisionNode::Ref(_) => expected_penalty += penalties.ref_
            }
        }

        assert_eq!(DecisionPenaltiesDepsImpl.nodes_penalty(&penalties, &net), expected_penalty);
    }

    #[hegel::test]
    fn test_leaf_penalty(tc: TestCase) {
        let penalties = tc.draw(gen_decision_penalties());
        let out_idx = tc.draw(gen_usize());

        let leaf_penalty = DecisionPenaltiesDepsImpl.leaf_penalty(&penalties, None);
        let non_leaf_penalty = DecisionPenaltiesDepsImpl.leaf_penalty(&penalties, Some(out_idx));

        assert_eq!(leaf_penalty, penalties.leaf);
        assert_eq!(non_leaf_penalty, penalties.non_leaf);
    }

    #[hegel::test]
    fn test_leaves_penalty(tc: TestCase) {
        let penalties = tc.draw(gen_decision_penalties());
        let net = tc.draw(gen_decision_net(None, None, None));
        let leaf_penalty = tc.draw(gen_f64());
        let n_leaves = net.nodes.len() * 2;

        let mut out_idxs = HashSet::new();
        for node in &net.nodes {
            out_idxs.insert(node.true_idx());
            out_idxs.insert(node.false_idx());
        }

        let mut mock_deps = MockDecisionPenaltiesDeps::new();

        let leaf_penalty_dep = mock_deps.expect_leaf_penalty().times(n_leaves);
        let hash_out_idxs = in_hash(out_idxs);
        let leaf_penalty_dep = leaf_penalty_dep.with(always(), hash_out_idxs);
        leaf_penalty_dep.return_const(leaf_penalty);

        let penalty = penalties._leaves_penalty(&mock_deps, &net);
        let expected_penalty = leaf_penalty * n_leaves as f64;

        assert_relative_eq!(penalty, expected_penalty, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_feats_penalty(tc: TestCase) {
        let n_feats = tc.draw(gen_usize_with_max(24)) + 1;
        let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));
        let penalties = tc.draw(gen_decision_penalties());
        let net = tc.draw(gen_decision_net(None, Some(&feat_ids), None));

        let mut used_feat_ids = std::collections::HashSet::new();
        for node in &net.nodes {
            if let DecisionNode::Branch(branch_node) = node
            && let Some(feat_id) = &branch_node.feat_id {
                used_feat_ids.insert(feat_id);
            }
        }

        let expected_penalty = penalties.used_feat + penalties.unused_feat;

        let mut mock_deps = MockDecisionPenaltiesDeps::new();
        let feats_penalty_from_counts_dep = mock_deps.expect_feats_penalty_from_counts().times(1);

        let eq_n_used = eq(used_feat_ids.len());
        let eq_n_feats = eq(n_feats);
        let feats_penalty_from_counts_dep = feats_penalty_from_counts_dep.with(always(), eq_n_used, eq_n_feats);

        feats_penalty_from_counts_dep.return_const(expected_penalty);

        assert_eq!(penalties._feats_penalty(&mock_deps, &net, n_feats), expected_penalty);
    }

    #[hegel::test]
    fn test_penalty(tc: TestCase) {
        let penalties = tc.draw(gen_decision_penalties());
        let net = tc.draw(gen_decision_net(None, None, None));

        let nodes_penalty = penalties.node + penalties.branch + penalties.ref_;
        let leaves_penalty = penalties.leaf + penalties.non_leaf;
        let feats_penalty = penalties.used_feat + penalties.unused_feat;

        let nodes_penalty_count = if nodes_penalty > 0.0 { 1 } else { 0 };
        let leaves_penalty_count = if leaves_penalty > 0.0 { 1 } else { 0 };
        let feats_penalty_count = if feats_penalty > 0.0 { 1 } else { 0 };

        let n_feats = tc.draw(gen_usize());

        let mut mock_deps = MockDecisionPenaltiesDeps::new();

        let nodes_penalty_dep = mock_deps.expect_nodes_penalty().times(nodes_penalty_count);
        let nodes_penalty_dep = nodes_penalty_dep.with(always(), always());
        nodes_penalty_dep.return_const(nodes_penalty);

        let leaves_penalty_dep = mock_deps.expect_leaves_penalty().times(leaves_penalty_count);
        let leaves_penalty_dep = leaves_penalty_dep.with(always(), always());
        leaves_penalty_dep.return_const(leaves_penalty);

        let eq_n_feats = eq(n_feats);

        let feats_penalty_dep = mock_deps.expect_feats_penalty().times(feats_penalty_count);
        let feats_penalty_dep = feats_penalty_dep.with(always(), always(), eq_n_feats);
        feats_penalty_dep.return_const(feats_penalty);

        let mut expected_penalty = nodes_penalty * nodes_penalty_count as f64;
        expected_penalty += leaves_penalty * leaves_penalty_count as f64;
        expected_penalty += feats_penalty * feats_penalty_count as f64;

        assert_eq!(penalties._penalty(&mock_deps, &net, n_feats), expected_penalty);
    }
}
