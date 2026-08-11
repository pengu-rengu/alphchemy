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

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct DecisionNet {
    pub nodes: Vec<DecisionNode>,
    pub max_trail_len: usize,
    pub default_value: bool,
    #[serde(skip)]
    pub idx_trail: Vec<usize>
}

#[cfg_attr(test, automock)]
trait DecisionNetDeps {
    fn eval_branch(&self, net: &DecisionNet, branch_node: &BranchNode, feat_table: &TimestampedTable, row: usize) -> Result<bool, String> {
        if let Some(feat_id) = branch_node.feat_id.as_ref()
        && let Some(threshold) = branch_node.threshold {
            let Some(col) = feat_table.table.get(feat_id) else {
                return Err(format!("Couldn't find feature with ID {feat_id} when evaluating branch node"))
            };
            let Some(value) = col.get(row) else {
                return Err(format!("Row {row} is out of bounds for feature ID {feat_id} when evaluating branch node"))
            };

            Ok(*value > threshold)
        } else {
            Ok(net.default_value)
        }
    }

    fn eval_ref(&self, net: &DecisionNet, ref_node: &RefNode) -> Result<bool, String> {
        match ref_node.ref_idx {
            None => Ok(net.default_value),
            Some(idx) => {
                let Some(node) = net.nodes.get(idx) else {
                    return Err(format!("Couldn't find node at {idx} when evaluating reference node"))
                };
                Ok(node.value())
            }
        }
    }

    fn next_idx(&self, node: &DecisionNode) -> Option<usize> {
        if node.value() { node.true_idx() } else { node.false_idx() }
    }

    fn update_idx(&self, net: &mut DecisionNet, current_idx: usize) -> Option<usize> {
        net._update_idx(&DecisionNetDepsImpl, current_idx).unwrap()
    }

    fn ptr_abs_idx(&self, node_ptr: &NodePtr, len: usize) -> Option<usize> {
        node_ptr.abs_idx(len)
    }
}

struct DecisionNetDepsImpl;
impl DecisionNetDeps for DecisionNetDepsImpl {}

impl DecisionNet {
    fn _update_idx<T>(&mut self, deps: &T, current_idx: usize) -> Result<Option<usize>, String> where T: DecisionNetDeps {
        let Some(node) = &self.nodes.get(current_idx) else {
            return Err(format!("Couldn't find decision node at {current_idx} when updating index"))
        };
        let next_idx = deps.next_idx(node);

        Ok(next_idx)
    }

    fn _eval<T>(&mut self, deps: &T, feat_table: &TimestampedTable, row: usize) -> Result<(), String> where T: DecisionNetDeps {
        if self.nodes.is_empty() { return Ok(()) }

        self.idx_trail.clear();

        let mut current_idx = Some(0);

        while let Some(node_idx) = current_idx {
            if self.idx_trail.len() >= self.max_trail_len {
                break;
            }

            let new_value = match &self.nodes[node_idx] {
                DecisionNode::Branch(branch_node) => deps.eval_branch(self, branch_node, feat_table, row)?,
                DecisionNode::Ref(ref_node) => deps.eval_ref(self, ref_node)?
            };

            self.nodes[node_idx].set_value(new_value);
            self.idx_trail.push(node_idx);
            current_idx = deps.update_idx(self, node_idx);
        }

        Ok(())
    }

    fn _node_value<T>(&self, deps: &T, net: &DecisionNet, node_ptr: &NodePtr) -> Result<bool, String> where T: DecisionNetDeps {
        let trail_len = self.idx_trail.len();
        let maybe_idx = deps.ptr_abs_idx(node_ptr, trail_len);

        Ok(match maybe_idx {
            Some(idx) => {
                let Some(node_idx) = net.idx_trail.get(idx) else {
                    return Err(format!("Couldn't find node index at {idx} when evaluating node value"))
                };
                let Some(node) = net.nodes.get(*node_idx) else {
                    return Err(format!("Couldn't find node at {node_idx} when evaluating node value"))
                };
                node.value()
            }
            None => net.default_value
        })
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
        self._eval(&DecisionNetDepsImpl, feat_table, row).unwrap();
    }

    fn node_value(&self, node_ptr: &NodePtr) -> bool {
        self._node_value(&DecisionNetDepsImpl, self, node_ptr).unwrap()
    }
}

#[derive(Clone, Copy, Debug, Serialize, PartialEq)]
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
pub mod tests {
    use super::*;
    use crate::{
        features::features::tests::gen_feat_table,
        network::network::tests::gen_node_ptr
    };
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize, gen_usize_with_max, gen_usize_with_min, gen_vec};
    use approx::assert_relative_eq;
    use hegel::{
        TestCase,
        generators::{booleans, sampled_from}
    };
    use mockall::predicate::{always, eq, in_hash};
    use std::cell::Cell;
    use std::collections::{HashMap, HashSet};
    use std::rc::Rc;

    #[hegel::composite]
    pub fn gen_branch_node(tc: TestCase, n_nodes: usize, draw_threshold: Option<bool>, feat_ids: Option<&[String]>, draw_feat_id: Option<bool>, draw_true_idx: Option<bool>, draw_false_idx: Option<bool>) -> BranchNode {
        let threshold = if draw_threshold.unwrap_or_else(|| tc.draw(booleans())) { Some(tc.draw(gen_f64())) } else { None };

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
    pub fn gen_ref_node(tc: TestCase, n_nodes: usize, draw_ref_idx: Option<bool>, draw_true_idx: Option<bool>, draw_false_idx: Option<bool>) -> RefNode {
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
    pub fn gen_decision_net(tc: TestCase, empty_nodes: Option<bool>, feat_ids: Option<&[String]>, empty_trail: Option<bool>) -> DecisionNet {
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

        DecisionNet { nodes, max_trail_len, default_value: tc.draw(booleans()), idx_trail }
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

    mod eval_branch_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            feat_value: f64,
            threshold: Option<f64>,
            default_value: bool,
            result: Result<bool, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_none_input: bool, draw_invalid: Option<bool>) -> TestContext {
            let feat_table = tc.draw(gen_feat_table());
            let feat_key_idx = tc.draw(gen_usize_with_max(feat_table.table.len() - 1));
            let feat_id = feat_table.table.keys().nth(feat_key_idx).unwrap();

            let draw_invalid = draw_invalid.unwrap_or_else(|| tc.draw(booleans()));
            let draw_invalid_feat_id = if draw_invalid { tc.draw(booleans()) } else { false };
            let draw_invalid_row = if draw_invalid {
                if draw_invalid_feat_id { tc.draw(booleans()) } else { true }
            } else { false };

            let feat_ids = vec![if draw_invalid_feat_id {
                let invalid_feat_id = tc.draw(gen_text());
                tc.assume(!feat_table.table.contains_key(&invalid_feat_id));
                invalid_feat_id
            } else { feat_id.to_string() }];
            let feat_values = feat_table.table[feat_id].clone();

            let n_values = feat_values.len();
            let row = tc.draw(gen_usize_with_max(feat_values.len() - 1));
            let net = tc.draw(gen_decision_net(Some(false), None, None));

            let branch_node = if draw_none_input {
                let node = tc.draw(gen_branch_node(net.nodes.len(), None, Some(&feat_ids), None, None, None));
                tc.assume(node.threshold.is_none() || node.feat_id.is_none());
                node
            } else {
                tc.draw(gen_branch_node(net.nodes.len(), Some(true), Some(&feat_ids), Some(true), None, None))
            };

            let input_row = if draw_invalid_row {
                tc.draw(gen_usize_with_min(n_values))
            } else { row };
            let result = DecisionNetDepsImpl.eval_branch(&net, &branch_node, &feat_table, input_row);

            TestContext {
                feat_value: feat_values[row],
                threshold: branch_node.threshold,
                default_value: net.default_value,
                result
            }
        }

        #[hegel::test]
        fn test_eval_branch(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, Some(false)));
            assert_eq!(ctx.result.unwrap(), ctx.feat_value > ctx.threshold.unwrap());
        }

        #[hegel::test]
        fn test_eval_branch_none(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, None));
            assert_eq!(ctx.result.unwrap(), ctx.default_value);
        }

        #[hegel::test]
        fn test_eval_branch_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, Some(true)));
            assert!(ctx.result.is_err());
        }
    }

    mod eval_ref_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_value: Option<bool>,
            default_value: bool,
            result: Result<bool, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_ref_idx: bool, draw_invalid: bool) -> TestContext {
            let net = tc.draw(gen_decision_net(Some(false), None, None));
            let mut ref_node = tc.draw(gen_ref_node(net.nodes.len(), Some(draw_ref_idx), None, None));
            if draw_invalid {
                ref_node.ref_idx = Some(tc.draw(gen_usize_with_min(net.nodes.len())));
            }

            let expected_value = if draw_invalid { None } else { ref_node.ref_idx.map(|idx| net.nodes[idx].value()) };

            let result = DecisionNetDepsImpl.eval_ref(&net, &ref_node);

            TestContext {
                expected_value,
                default_value: net.default_value,
                result
            }
        }

        #[hegel::test]
        fn test_eval_ref(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, false));
            assert_eq!(ctx.result.unwrap(), ctx.expected_value.unwrap());
        }

        #[hegel::test]
        fn test_eval_ref_no_idx(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, false));
            assert_eq!(ctx.result.unwrap(), ctx.default_value);
        }

        #[hegel::test]
        fn test_eval_ref_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, true));
            assert!(ctx.result.is_err());
        }
    }

    mod next_idx_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            node: DecisionNode,
            result: Option<usize>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_true_path: bool) -> TestContext {
            let net = tc.draw(gen_decision_net(Some(false), None, None));
            let n_nodes = net.nodes.len();

            let node = if tc.draw(booleans()) {
                DecisionNode::Branch(tc.draw(if draw_true_path {
                    gen_branch_node(n_nodes, None, None, None, None, Some(false))
                } else {
                    gen_branch_node(n_nodes, None, None, None, Some(false), None)
                }))
            } else {
                DecisionNode::Ref(tc.draw(if draw_true_path {
                    gen_ref_node(n_nodes, None, None, Some(false))
                } else {
                    gen_ref_node(n_nodes, None, Some(false), None)
                }))
            };
            let result = DecisionNetDepsImpl.next_idx(&node);

            TestContext { result, node }
        }

        #[hegel::test]
        fn test_next_idx_true(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            let node = ctx.node;

            assert_eq!(ctx.result, if node.value() { node.true_idx() } else { None });
        }

        #[hegel::test]
        fn test_next_idx_false(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            let node = ctx.node;

            assert_eq!(ctx.result, if node.value() { None } else { node.false_idx() })
        }
    }

    mod update_idx_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_next_idx: usize,
            result: Result<Option<usize>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_none_idx: bool, draw_invalid: bool) -> TestContext {
            let mut net = tc.draw(gen_decision_net(Some(false), None, Some(true)));
            let n_nodes = net.nodes.len();

            let current_idx = tc.draw(if draw_invalid {
                gen_usize_with_min(n_nodes)
            } else {
                gen_usize_with_max(n_nodes - 1)
            });
            let expected_next_idx = tc.draw(gen_usize());

            let mut mock_deps = MockDecisionNetDeps::new();

            if !draw_invalid {
                let eq_node = eq(net.nodes[current_idx].clone());

                mock_deps.expect_next_idx()
                    .times(1)
                    .with(eq_node)
                    .return_const(if draw_none_idx { None } else { Some(expected_next_idx) });
            }
            
            let result = net._update_idx(&mock_deps, current_idx);

            TestContext {
                expected_next_idx,
                result
            }
        }

        #[hegel::test]
        fn test_update_idx(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, false));
            assert_eq!(ctx.result.unwrap(), Some(ctx.expected_next_idx));
        }

        #[hegel::test]
        fn test_update_idx_none(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, false));
            assert!(ctx.result.unwrap().is_none());
        }

        #[hegel::test]
        fn test_update_idx_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, true));
            assert!(ctx.result.is_err())
        }
    }

    mod net_eval_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_trail: Vec<usize>,
            expected_values: HashMap<usize, bool>,
            net: DecisionNet,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let feat_table = tc.draw(gen_feat_table());
            let mut net = tc.draw(gen_decision_net(Some(false), None, Some(true)));

            let idx_gen = gen_usize_with_max(net.nodes.len() - 1);
            let mut expected_trail = tc.draw(gen_vec(idx_gen, tc.draw(gen_usize())));
            expected_trail.insert(0, 0);
            net.max_trail_len = expected_trail.len();
            let expected_trail = Rc::new(expected_trail);
            
            let invalid_idx = tc.draw(gen_usize_with_max(net.max_trail_len - 1));

            let expected_values = Rc::new(expected_trail.iter().map(|idx| (*idx, tc.draw(booleans()))).collect::<HashMap<usize, bool>>());
            let trail_idx = Rc::new(Cell::new(0));

            let mut mock_deps = MockDecisionNetDeps::new();

            let expected_trail_branch = Rc::clone(&expected_trail);
            let expected_values_branch = Rc::clone(&expected_values);
            let trail_idx_branch = Rc::clone(&trail_idx);
            mock_deps.expect_eval_branch()
                .with(always(), always(), always(), always())
                .returning_st(move |_, _, _, _| {
                let idx = trail_idx_branch.get();
                if draw_invalid && idx == invalid_idx { Err(String::new()) } else { Ok(expected_values_branch[&expected_trail_branch[idx]]) }
            });

            let expected_trail_ref = Rc::clone(&expected_trail);
            let expected_values_ref = Rc::clone(&expected_values);
            let trail_idx_ref = Rc::clone(&trail_idx);
            mock_deps.expect_eval_ref()
                .with(always(), always())
                .returning_st(move |_, _| {
                let idx = trail_idx_ref.get();
                if draw_invalid && idx == invalid_idx { Err(String::new()) } else { Ok(expected_values_ref[&expected_trail_ref[trail_idx_ref.get()]]) } 
            });

            let expected_trail_update = Rc::clone(&expected_trail);
            let trail_idx_update = Rc::clone(&trail_idx);
            mock_deps.expect_update_idx()
                .with(always(), always())
                .returning_st(move |_, _| {
                let idx = trail_idx_update.get();
                let new_idx = idx + 1;
                trail_idx_update.set(new_idx);
                if new_idx >= expected_trail_update.len() { None } else { Some(expected_trail_update[new_idx]) }
            });

            let result = net._eval(&mock_deps, &feat_table, 0);

            TestContext {
                expected_trail: (*expected_trail).clone(),
                expected_values: (*expected_values).clone(),
                net: net,
                result: result
            }
        }

        #[hegel::test]
        fn test_net_eval(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));

            assert_eq!(ctx.net.idx_trail, ctx.expected_trail);
            for (node_idx, expected_value) in ctx.expected_values {
                assert_eq!(ctx.net.nodes[node_idx].value(), expected_value);
            }
        }

        #[hegel::test]
        fn test_net_eval_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err())
        }
    }

    mod node_value_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_value: Option<bool>,
            default_value: bool,
            result: Result<bool, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_no_idx: bool, draw_invalid: bool) -> TestContext {
            let mut net = tc.draw(gen_decision_net(Some(false), None, Some(false)));
            let node_ptr = tc.draw(gen_node_ptr(net.idx_trail.len(), None, false));

            let draw_invalid_trail_idx = if draw_invalid { tc.draw(booleans())  } else { false };
            let draw_invalid_node_idx = if draw_invalid { !draw_invalid_trail_idx } else { false };

            let trail_idx = tc.draw(if draw_invalid_trail_idx {
                gen_usize_with_min(net.idx_trail.len())
            } else { 
                gen_usize_with_max(net.idx_trail.len() - 1) 
            });

            if draw_invalid_node_idx {
                net.idx_trail[trail_idx] = tc.draw(gen_usize_with_min(net.nodes.len()));
            }

            let mut mock_deps = MockDecisionNetDeps::new();

            let eq_node_ptr = eq(node_ptr.clone());
            let eq_trail_len = eq(net.idx_trail.len());

            mock_deps.expect_ptr_abs_idx()
                .times(1)
                .with(eq_node_ptr, eq_trail_len)
                .return_const_st(if draw_no_idx { None } else { Some(trail_idx) });

            let result = net._node_value(&mock_deps, &net, &node_ptr);

            TestContext {
                expected_value: if draw_no_idx || draw_invalid { None } else { Some(net.nodes[net.idx_trail[trail_idx]].value()) },
                default_value: net.default_value,
                result
            }
        }

        #[hegel::test]
        fn test_node_value(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, false));
            assert_eq!(ctx.result.unwrap(), ctx.expected_value.unwrap());
        }

        #[hegel::test]
        fn test_node_value_no_idx(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, false));
            assert_eq!(ctx.result.unwrap(), ctx.default_value);
        }
        
        #[hegel::test]
        fn test_node_value_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, true));
            assert!(ctx.result.is_err());
        }
        
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

        let result = DecisionPenaltiesDepsImpl.nodes_penalty(&penalties, &net);
        assert_eq!(result, expected_penalty);
    }

    mod leaf_penalty_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            penalties: DecisionPenalties,
            result: f64
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_none_idx: bool) -> TestContext {
            let penalties = tc.draw(gen_decision_penalties());
            let out_idx = if draw_none_idx { None } else { Some(tc.draw(gen_usize())) };

            let result = DecisionPenaltiesDepsImpl.leaf_penalty(&penalties, out_idx);

            TestContext { penalties, result }
        }

        #[hegel::test]
        fn test_leaf_penalty(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert_eq!(ctx.result, ctx.penalties.leaf);
        }

        #[hegel::test]
        fn test_non_leaf_penalty(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, ctx.penalties.non_leaf);
        }
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

        let hash_out_idxs = in_hash(out_idxs);

        mock_deps.expect_leaf_penalty()
            .times(n_leaves)
            .with(always(), hash_out_idxs)
            .return_const(leaf_penalty);

        let penalty = penalties._leaves_penalty(&mock_deps, &net);

        assert_relative_eq!(penalty, leaf_penalty * n_leaves as f64, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_feats_penalty(tc: TestCase) {
        let n_feats = tc.draw(gen_usize_with_max(24)) + 1;
        let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));
        let penalties = tc.draw(gen_decision_penalties());
        let net = tc.draw(gen_decision_net(None, Some(&feat_ids), None));

        let mut used_feat_ids = HashSet::new();
        for node in &net.nodes {
            if let DecisionNode::Branch(branch_node) = node
            && let Some(feat_id) = &branch_node.feat_id {
                used_feat_ids.insert(feat_id);
            }
        }

        let expected_penalty = penalties.used_feat + penalties.unused_feat;

        let mut mock_deps = MockDecisionPenaltiesDeps::new();

        let eq_n_used = eq(used_feat_ids.len());
        let eq_n_feats = eq(n_feats);
        
        mock_deps.expect_feats_penalty_from_counts()
            .times(1)
            .with(always(), eq_n_used, eq_n_feats)
            .return_const(expected_penalty);

        let result = penalties._feats_penalty(&mock_deps, &net, n_feats);
        assert_relative_eq!(result, expected_penalty, epsilon = 1e-5);
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

        mock_deps.expect_nodes_penalty()
            .times(nodes_penalty_count)
            .with(always(), always())
            .return_const(nodes_penalty);

        mock_deps.expect_leaves_penalty()
            .times(leaves_penalty_count)
            .with(always(), always())
            .return_const(leaves_penalty);

        let eq_n_feats = eq(n_feats);

        mock_deps.expect_feats_penalty()
            .times(feats_penalty_count)
            .with(always(), always(), eq_n_feats)
            .return_const(feats_penalty);

        let mut expected_penalty = nodes_penalty * nodes_penalty_count as f64;
        expected_penalty += leaves_penalty * leaves_penalty_count as f64;
        expected_penalty += feats_penalty * feats_penalty_count as f64;

        let result = penalties._penalty(&mock_deps, &net, n_feats);
        assert_relative_eq!(result, expected_penalty, epsilon = 1e-5);
    }
}
