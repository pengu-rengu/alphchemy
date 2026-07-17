use std::collections::HashSet;
use serde::Serialize;
use serde_json::Value;
#[cfg(test)]
use mockall::automock;
use crate::features::features::TimestampedTable;
use crate::network::network::{Network, NodePtr, Penalties, feats_penalty_from_counts};
use crate::utils::to_json_with_tag;

#[derive(Clone, Copy, Debug, Serialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum Gate { And, Or, Xor, Nand, Nor, Xnor }

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct InputNode {
    pub threshold: Option<f64>,
    pub feat_id: Option<String>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct GateNode {
    pub gate: Option<Gate>,
    pub in1_idx: Option<usize>,
    pub in2_idx: Option<usize>,
    #[serde(skip)]
    pub value: bool
}

#[derive(Clone, Debug, Serialize, PartialEq)]
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

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct LogicNet {
    pub nodes: Vec<LogicNode>,
    pub default_value: bool
}

#[cfg_attr(test, automock)]
trait LogicNetDeps {
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

    fn ptr_abs_idx(&self, node_ptr: &NodePtr, len: usize) -> Option<usize> {
        node_ptr.abs_idx(len)
    }
}

struct LogicNetDepsImpl;
impl LogicNetDeps for LogicNetDepsImpl {}

impl LogicNet {

    fn _eval_gate<T>(&self, deps: &T, gate_node: &GateNode) -> bool where T: LogicNetDeps  {

        let value1 = deps.input_value(self, gate_node.in1_idx);
        let value2 = deps.input_value(self, gate_node.in2_idx);

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
                LogicNode::Input(input_node) => deps.eval_input(self, input_node, feat_table, row),
                LogicNode::Gate(gate_node) => deps.eval_gate(self, gate_node)
            };

            self.nodes[i].set_value(new_value);
        }
    }

    fn _node_value<T>(&self, deps: &T, node_ptr: &NodePtr) -> bool where T: LogicNetDeps {
        let maybe_idx = deps.ptr_abs_idx(node_ptr, self.nodes.len());

        match maybe_idx {
            Some(idx) => self.nodes[idx].value(),
            None => self.default_value
        }
    }
}


impl Network for LogicNet {

    fn to_json(&self) -> Value {
        to_json_with_tag(self, "type", "logic")
    }

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

#[derive(Clone, Debug, Serialize, PartialEq)]
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

    fn directions_penalty(&self, penalties: &LogicPenalties, net: &LogicNet) -> f64 {
        penalties._directions_penalty(LogicPenaltiesDepsImpl, net)
    }

    fn feats_penalty_from_counts(&self, penalties: &LogicPenalties, n_used: usize, n_feats: usize) -> f64 {
        feats_penalty_from_counts(n_used, n_feats, penalties.used_feat, penalties.unused_feat)
    }

    fn feats_penalty(&self, penalties: &LogicPenalties, net: &LogicNet, n_feats: usize) -> f64 {
        penalties._feats_penalty(LogicPenaltiesDepsImpl, net, n_feats)
    }
}

struct LogicPenaltiesDepsImpl;
impl LogicPenaltiesDeps for LogicPenaltiesDepsImpl {}

impl LogicPenalties {

    fn _directions_penalty<T>(&self, deps: T, net: &LogicNet) -> f64 where T: LogicPenaltiesDeps {
        net.nodes.iter().enumerate().map(|(idx, node)| {
            let mut penalty = 0.0;

            if let LogicNode::Gate(gate_node) = node {
                penalty += deps.direction_penalty(self, gate_node.in1_idx, idx);
                penalty += deps.direction_penalty(self, gate_node.in2_idx, idx);
            }

            penalty
        }).sum()
    }

    fn _feats_penalty<T>(&self, deps: T, net: &LogicNet, n_feats: usize) -> f64 where T: LogicPenaltiesDeps {
        let mut used_feat_ids = HashSet::new();

        for node in &net.nodes {
            if let LogicNode::Input(input_node) = node
            && let Some(feat_id) = &input_node.feat_id {
                used_feat_ids.insert(feat_id);
            }
        }

        deps.feats_penalty_from_counts(self, used_feat_ids.len(), n_feats)
    }

    fn _penalty<T>(&self, deps: T, net: &LogicNet, n_feats: usize) -> f64 where T: LogicPenaltiesDeps {
        let mut penalty = 0.0;

        if self.node + self.input + self.gate > 0.0 {
            penalty += deps.nodes_penalty(self, net);
        }

        if self.recurrence + self.feedforward > 0.0 {
            penalty += deps.directions_penalty(self, net);
        }

        if self.used_feat + self.unused_feat > 0.0 {
            penalty += deps.feats_penalty(self, net, n_feats);
        }

        penalty
    }
}

impl Penalties<LogicNet> for LogicPenalties {
    fn to_json(&self) -> Value {
        to_json_with_tag(self, "type", "logic")
    }

    fn penalty(&self, net: &LogicNet, n_feats: usize) -> f64 {
        self._penalty(LogicPenaltiesDepsImpl, net, n_feats)
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use crate::features::features::tests::gen_feat_table;
    use crate::network::network::tests::gen_node_ptr;
    use crate::test_utils::{
        gen_f64, gen_text, gen_usize, gen_usize_with_max, gen_usize_with_min, gen_vec
    };
    use approx::assert_relative_eq;
    use hegel::TestCase;
    use hegel::generators::{booleans, sampled_from};
    use mockall::predicate::{always, eq, in_hash};
    use std::cell::Cell;
    use std::rc::Rc;
    use std::vec;

    #[hegel::composite]
    pub fn gen_input_node(
        tc: TestCase,
        draw_threshold: Option<bool>,
        feat_ids: Option<&[String]>,
        draw_feat_id: Option<bool>
    ) -> InputNode {
        let threshold = if draw_threshold.unwrap_or_else(|| tc.draw(booleans())) {
            let rand_threshold = tc.draw(gen_f64());
            Some(rand_threshold)
        } else {
            None
        };

        let feat_id = if draw_feat_id.unwrap_or_else(|| tc.draw(booleans())) {
            let ids = match feat_ids {
                Some(ids) => ids,
                None => {
                    let n_feats = tc.draw(gen_usize_with_max(9)) + 1;
                    &tc.draw(gen_vec(gen_text(), n_feats))
                }
            };
            Some(tc.draw(sampled_from(ids)))
        } else {
            None
        };

        InputNode {
            threshold,
            feat_id,
            value: tc.draw(booleans())
        }
    }

    #[hegel::composite]
    pub fn gen_gate_node(
        tc: TestCase,
        n_nodes: usize,
        draw_gate: Option<bool>,
        draw_in1_idx: Option<bool>,
        draw_in2_idx: Option<bool>
    ) -> GateNode {
        let gate = if draw_gate.unwrap_or_else(|| tc.draw(booleans())) {
            let rand_gate = tc.draw(sampled_from(vec![
                Gate::And,
                Gate::Or,
                Gate::Xor,
                Gate::Nand,
                Gate::Nor,
                Gate::Xnor
            ]));
            Some(rand_gate)
        } else {
            None
        };

        let max_idx = n_nodes - 1;
        let in1_idx = if draw_in1_idx.unwrap_or_else(|| tc.draw(booleans())) {
            let idx = tc.draw(gen_usize_with_max(max_idx));
            Some(idx)
        } else {
            None
        };
        let in2_idx = if draw_in2_idx.unwrap_or_else(|| tc.draw(booleans())) {
            let idx = tc.draw(gen_usize_with_max(max_idx));
            Some(idx)
        } else {
            None
        };

        GateNode {
            gate,
            in1_idx,
            in2_idx,
            value: tc.draw(booleans())
        }
    }

    #[hegel::composite]
    pub fn gen_logic_net(
        tc: TestCase,
        empty: Option<bool>,
        feat_ids: Option<&[String]>
    ) -> LogicNet {
        let n_nodes = if empty.unwrap_or_else(|| tc.draw(booleans())) {
            0
        } else {
            tc.draw(gen_usize_with_min(1))
        };
        let nodes = (0..n_nodes)
            .map(|_| {
                if tc.draw(booleans()) {
                    let input_node = tc.draw(gen_input_node(None, feat_ids, None));
                    LogicNode::Input(input_node)
                } else {
                    let gate_node = tc.draw(gen_gate_node(n_nodes, None, None, None));
                    LogicNode::Gate(gate_node)
                }
            })
            .collect();

        LogicNet {
            nodes,
            default_value: tc.draw(booleans())
        }
    }

    #[hegel::composite]
    pub fn gen_logic_penalties(tc: TestCase) -> LogicPenalties {
        let node_penalty = tc.draw(gen_f64());
        let input_penalty = tc.draw(gen_f64());
        let gate_penalty = tc.draw(gen_f64());
        let rec_penalty = tc.draw(gen_f64());
        let feedforward_penalty = tc.draw(gen_f64());
        let used_feat_penalty = tc.draw(gen_f64());
        let unused_feat_penalty = tc.draw(gen_f64());

        LogicPenalties {
            node: node_penalty,
            input: input_penalty,
            gate: gate_penalty,
            recurrence: rec_penalty,
            feedforward: feedforward_penalty,
            used_feat: used_feat_penalty,
            unused_feat: unused_feat_penalty
        }
    }

    mod eval_input_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            net: LogicNet,
            feat_table: TimestampedTable,
            feat_ids: Vec<String>,
            feat_values: Vec<f64>,
            row: usize
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase) -> TestContext {
            let feat_table = tc.draw(gen_feat_table());
            let feat_key_idx = tc.draw(gen_usize_with_max(feat_table.table.len() - 1));
            let feat_id = feat_table.table.keys().nth(feat_key_idx).unwrap();
            let feat_ids = vec![feat_id.to_string()];
            let feat_values = feat_table.table[feat_id].clone();
            let row = tc.draw(gen_usize_with_max(feat_values.len() - 1));
            let net = tc.draw(gen_logic_net(None, Some(&feat_ids)));

            TestContext {
                net,
                feat_table,
                feat_ids,
                feat_values,
                row
            }
        }

        #[hegel::test]
        fn test_eval_input(tc: TestCase) {
            let ctx = tc.draw(gen_context());

            let input_node = tc.draw(gen_input_node(Some(true), Some(&ctx.feat_ids), Some(true)));

            let value =
                LogicNetDepsImpl.eval_input(&ctx.net, &input_node, &ctx.feat_table, ctx.row);
            assert_eq!(
                value,
                ctx.feat_values[ctx.row] > input_node.threshold.unwrap()
            );
        }

        #[hegel::test]
        fn test_eval_input_no_thresh(tc: TestCase) {
            let ctx = tc.draw(gen_context());

            let input_node = tc.draw(gen_input_node(Some(false), Some(&ctx.feat_ids), Some(true)));

            let value =
                LogicNetDepsImpl.eval_input(&ctx.net, &input_node, &ctx.feat_table, ctx.row);
            assert_eq!(value, ctx.net.default_value);
        }

        #[hegel::test]
        fn test_eval_input_no_feat(tc: TestCase) {
            let ctx = tc.draw(gen_context());

            let input_node = tc.draw(gen_input_node(Some(true), None, Some(false)));

            let value =
                LogicNetDepsImpl.eval_input(&ctx.net, &input_node, &ctx.feat_table, ctx.row);
            assert_eq!(value, ctx.net.default_value);
        }

        #[hegel::test]
        fn test_eval_input_no_thresh_feat(tc: TestCase) {
            let ctx = tc.draw(gen_context());

            let input_node = tc.draw(gen_input_node(Some(false), None, Some(false)));

            let value =
                LogicNetDepsImpl.eval_input(&ctx.net, &input_node, &ctx.feat_table, ctx.row);
            assert_eq!(value, ctx.net.default_value);
        }
    }

    mod input_value_tests {
        use super::*;

        #[hegel::test]
        fn test_input_value(tc: TestCase) {
            let net = tc.draw(gen_logic_net(Some(false), None));
            let idx = tc.draw(gen_usize_with_max(net.nodes.len() - 1));

            let value = LogicNetDepsImpl.input_value(&net, Some(idx));

            assert_eq!(value, net.nodes[idx].value());
        }

        #[hegel::test]
        fn test_input_value_no_idx(tc: TestCase) {
            let net = tc.draw(gen_logic_net(Some(false), None));

            let value = LogicNetDepsImpl.input_value(&net, None);

            assert_eq!(value, net.default_value);
        }
    }

    mod eval_gate_tests {
        use super::*;

        fn eval_gate(tc: TestCase, gate: Gate) -> (bool, bool, bool) {
            let net = tc.draw(gen_logic_net(Some(false), None));
            let mut gate_node = tc.draw(gen_gate_node(
                net.nodes.len(),
                Some(true),
                Some(true),
                Some(true)
            ));
            let in1_value = tc.draw(booleans());
            let in2_value = if gate_node.in1_idx == gate_node.in2_idx {
                in1_value
            } else {
                tc.draw(booleans())
            };
            let mut mock_deps = MockLogicNetDeps::new();
            let eq_net = eq(net.clone());
            let eq_in1_idx = eq(Some(gate_node.in1_idx.unwrap()));
            let input_value1_dep = mock_deps
                .expect_input_value()
                .with(eq_net.clone(), eq_in1_idx);
            input_value1_dep.return_const(in1_value);
            let eq_in2_idx = eq(Some(gate_node.in2_idx.unwrap()));
            let input_value2_dep = mock_deps.expect_input_value().with(eq_net, eq_in2_idx);
            input_value2_dep.return_const(in2_value);
            gate_node.gate = Some(gate);

            let value = net._eval_gate(&mock_deps, &gate_node);

            (value, in1_value, in2_value)
        }

        #[hegel::test]
        fn test_eval_gate_and(tc: TestCase) {
            let (value, in1_value, in2_value) = eval_gate(tc, Gate::And);
            assert_eq!(value, in1_value && in2_value);
        }

        #[hegel::test]
        fn test_eval_gate_or(tc: TestCase) {
            let (value, in1_value, in2_value) = eval_gate(tc, Gate::Or);
            assert_eq!(value, in1_value || in2_value);
        }

        #[hegel::test]
        fn test_eval_gate_xor(tc: TestCase) {
            let (value, in1_value, in2_value) = eval_gate(tc, Gate::Xor);
            assert_eq!(value, in1_value ^ in2_value);
        }

        #[hegel::test]
        fn test_eval_gate_nand(tc: TestCase) {
            let (value, in1_value, in2_value) = eval_gate(tc, Gate::Nand);
            assert_eq!(value, !(in1_value && in2_value));
        }

        #[hegel::test]
        fn test_eval_gate_nor(tc: TestCase) {
            let (value, in1_value, in2_value) = eval_gate(tc, Gate::Nor);
            assert_eq!(value, !(in1_value || in2_value));
        }

        #[hegel::test]
        fn test_eval_gate_xnor(tc: TestCase) {
            let (value, in1_value, in2_value) = eval_gate(tc, Gate::Xnor);
            assert_eq!(value, !(in1_value ^ in2_value));
        }
    }

    mod net_eval_tests {
        use super::*;

        #[hegel::test]
        fn test_net_eval(tc: TestCase) {
            let feat_table = tc.draw(gen_feat_table());
            let mut net = tc.draw(gen_logic_net(None, None));
            let n_nodes = net.nodes.len();
            let mut n_input_nodes = 0;
            let mut n_gate_nodes = 0;
            for node in &net.nodes {
                match node {
                    LogicNode::Input(_) => n_input_nodes += 1,
                    LogicNode::Gate(_) => n_gate_nodes += 1
                }
            }
            let mut mock_deps = MockLogicNetDeps::new();

            let expected_values = Rc::new(tc.draw(gen_vec(booleans(), n_nodes)));
            let node_idx = Rc::new(Cell::new(0));

            let eval_input_dep = mock_deps.expect_eval_input().times(n_input_nodes);
            let eval_input_dep = eval_input_dep.with(always(), always(), always(), always());

            let node_idx_input = Rc::clone(&node_idx);
            let expected_values_input = Rc::clone(&expected_values);
            eval_input_dep.returning_st(move |_, _, _, _| {
                let idx = node_idx_input.get();
                let value = expected_values_input[idx];
                node_idx_input.set(idx + 1);
                value
            });

            let eval_gate_dep = mock_deps.expect_eval_gate().times(n_gate_nodes);
            let eval_gate_dep = eval_gate_dep.with(always(), always());

            let node_idx_gate = Rc::clone(&node_idx);
            let expected_values_gate = Rc::clone(&expected_values);
            eval_gate_dep.returning_st(move |_, _| {
                let idx = node_idx_gate.get();
                let value = expected_values_gate[idx];
                node_idx_gate.set(idx + 1);
                value
            });

            net._eval(&mock_deps, &feat_table, 0);

            assert_eq!(node_idx.get(), n_nodes);
            for i in 0..net.nodes.len() {
                assert_eq!(net.nodes[i].value(), expected_values[i]);
            }
        }
    }

    mod node_value_tests {
        use super::*;

        #[hegel::test]
        fn test_node_value(tc: TestCase) {
            let net = tc.draw(gen_logic_net(Some(false), None));
            let n_nodes = net.nodes.len();
            let node_ptr = tc.draw(gen_node_ptr(n_nodes, None, false));
            let expected_idx = tc.draw(gen_usize_with_max(n_nodes - 1));
            let mut mock_deps = MockLogicNetDeps::new();
            let eq_node_ptr = eq(node_ptr.clone());
            let eq_len = eq(n_nodes);
            let ptr_abs_idx_dep = mock_deps.expect_ptr_abs_idx().times(1);
            let ptr_abs_idx_dep = ptr_abs_idx_dep.with(eq_node_ptr, eq_len);
            ptr_abs_idx_dep.return_const_st(Some(expected_idx));

            let value = net._node_value(&mock_deps, &node_ptr);

            assert_eq!(value, net.nodes[expected_idx].value());
        }

        #[hegel::test]
        fn test_node_value_no_idx(tc: TestCase) {
            let net = tc.draw(gen_logic_net(Some(false), None));
            let n_nodes = net.nodes.len();
            let node_ptr = tc.draw(gen_node_ptr(n_nodes, None, false));
            let mut mock_deps = MockLogicNetDeps::new();
            let eq_node_ptr = eq(node_ptr.clone());
            let eq_len = eq(n_nodes);
            let ptr_abs_idx_dep = mock_deps.expect_ptr_abs_idx().times(1);
            let ptr_abs_idx_dep = ptr_abs_idx_dep.with(eq_node_ptr, eq_len);
            ptr_abs_idx_dep.return_const_st(None);

            let value = net._node_value(&mock_deps, &node_ptr);

            assert_eq!(value, net.default_value);
        }
    }

    mod nodes_penalty_tests {
        use super::*;

        #[hegel::test]
        fn test_nodes_penalty(tc: TestCase) {
            let penalties = tc.draw(gen_logic_penalties());
            let net = tc.draw(gen_logic_net(None, None));

            let mut expected_penalty = 0.0;
            for node in &net.nodes {
                expected_penalty += penalties.node;
                match node {
                    LogicNode::Input(_) => expected_penalty += penalties.input,
                    LogicNode::Gate(_) => expected_penalty += penalties.gate
                }
            }

            assert_eq!(
                LogicPenaltiesDepsImpl.nodes_penalty(&penalties, &net),
                expected_penalty
            )
        }
    }

    mod direction_penalty_tests {
        use super::*;

        #[hegel::test]
        fn test_direction_penalty_recurrence(tc: TestCase) {
            let penalties = tc.draw(gen_logic_penalties());
            let idx = tc.draw(gen_usize());
            let in_idx = tc.draw(gen_usize_with_min(idx));

            let penalty = LogicPenaltiesDepsImpl.direction_penalty(&penalties, Some(in_idx), idx);

            assert_eq!(penalty, penalties.recurrence);
        }

        #[hegel::test]
        fn test_direction_penalty_feedforward(tc: TestCase) {
            let penalties = tc.draw(gen_logic_penalties());
            let idx = tc.draw(gen_usize());
            let in_idx = tc.draw(gen_usize_with_max(idx));

            let penalty =
                LogicPenaltiesDepsImpl.direction_penalty(&penalties, Some(in_idx), idx + 1);

            assert_eq!(penalty, penalties.feedforward);
        }

        #[hegel::test]
        fn test_direction_penalty_no_input(tc: TestCase) {
            let penalties = tc.draw(gen_logic_penalties());
            let idx = tc.draw(gen_usize());

            let penalty = LogicPenaltiesDepsImpl.direction_penalty(&penalties, None, idx);

            assert_eq!(penalty, 0.0);
        }
    }

    mod directions_penalty_tests {
        use super::*;

        #[hegel::test]
        fn test_directions_penalty(tc: TestCase) {
            let penalties = tc.draw(gen_logic_penalties());
            let net = tc.draw(gen_logic_net(None, None));

            let direction_penalty = penalties.recurrence + penalties.feedforward;

            let mut in_indices = HashSet::new();
            let mut indices = HashSet::new();
            let mut expected_penalty = 0.0;

            for (idx, node) in net.nodes.iter().enumerate() {
                if let LogicNode::Gate(gate_node) = node {
                    in_indices.extend(vec![gate_node.in1_idx, gate_node.in2_idx]);
                    indices.extend(vec![idx, idx]);
                    expected_penalty += direction_penalty * 2.0;
                }
            }

            let mut mock_deps = MockLogicPenaltiesDeps::new();

            let eq_penalties = eq(penalties.clone());
            let hash_in_indices = in_hash(in_indices);
            let hash_indices = in_hash(indices);

            let direction_penalty_dep = mock_deps.expect_direction_penalty().with(
                eq_penalties,
                hash_in_indices,
                hash_indices
            );
            direction_penalty_dep.return_const(direction_penalty);
            let penalty = penalties._directions_penalty(mock_deps, &net);

            assert_relative_eq!(penalty, expected_penalty, epsilon = 1e-5)
        }
    }

    mod feats_penalty_tests {
        use super::*;

        #[hegel::test]
        fn test_feats_penalty(tc: TestCase) {
            let expected_n_feats = tc.draw(gen_usize_with_max(24)) + 1;
            let feat_ids = tc.draw(gen_vec(gen_text(), expected_n_feats));
            let penalties = tc.draw(gen_logic_penalties());
            let net = tc.draw(gen_logic_net(None, Some(&feat_ids)));

            let mut used_feat_ids = HashSet::new();
            for node in &net.nodes {
                if let LogicNode::Input(input_node) = node
                    && let Some(feat_id) = &input_node.feat_id
                {
                    used_feat_ids.insert(feat_id);
                }
            }

            let expected_penalty = penalties.used_feat + penalties.unused_feat;

            let mut mock_deps = MockLogicPenaltiesDeps::new();
            let feats_penalty_from_counts_dep =
                mock_deps.expect_feats_penalty_from_counts().times(1);

            let eq_penalties = eq(penalties.clone());
            let eq_n_used = eq(used_feat_ids.len());
            let eq_n_feats = eq(expected_n_feats);

            let feats_penalty_from_counts_dep =
                feats_penalty_from_counts_dep.with(eq_penalties, eq_n_used, eq_n_feats);

            feats_penalty_from_counts_dep.return_const(expected_penalty);

            assert_eq!(
                penalties._feats_penalty(mock_deps, &net, expected_n_feats),
                expected_penalty
            );
        }
    }

    mod penalty_tests {
        use super::*;

        #[hegel::test]
        fn test_penalty(tc: TestCase) {
            let penalties = tc.draw(gen_logic_penalties());
            let net = tc.draw(gen_logic_net(None, None));

            let nodes_penalty = penalties.node + penalties.input + penalties.gate;
            let directions_penalty = penalties.recurrence + penalties.feedforward;
            let feats_penalty = penalties.used_feat + penalties.unused_feat;

            let nodes_penalty_count = if nodes_penalty > 0.0 { 1 } else { 0 };
            let directions_penalty_count = if directions_penalty > 0.0 { 1 } else { 0 };
            let feats_penalty_count = if feats_penalty > 0.0 { 1 } else { 0 };

            println!("{}", nodes_penalty);

            let n_feats = tc.draw(gen_usize());

            let mut mock_deps = MockLogicPenaltiesDeps::new();

            let eq_penalties = eq(penalties.clone());
            let eq_net = eq(net.clone());

            let nodes_penalty_dep = mock_deps.expect_nodes_penalty().times(nodes_penalty_count);
            let nodes_penalty_dep = nodes_penalty_dep.with(eq_penalties.clone(), eq_net.clone());
            nodes_penalty_dep.return_const(nodes_penalty);

            let directions_penalty_dep = mock_deps
                .expect_directions_penalty()
                .times(directions_penalty_count);
            let directions_penalty_dep =
                directions_penalty_dep.with(eq_penalties.clone(), eq_net.clone());
            directions_penalty_dep.return_const(directions_penalty);

            let eq_n_feats = eq(n_feats);

            let feats_penalty_dep = mock_deps.expect_feats_penalty().times(feats_penalty_count);
            let feats_penalty_dep = feats_penalty_dep.with(eq_penalties, eq_net, eq_n_feats);
            feats_penalty_dep.return_const(feats_penalty);

            let mut expected_penalty = nodes_penalty * nodes_penalty_count as f64;
            expected_penalty += directions_penalty * directions_penalty_count as f64;
            expected_penalty += feats_penalty * feats_penalty_count as f64;

            assert_eq!(
                penalties._penalty(mock_deps, &net, n_feats),
                expected_penalty
            );
        }
    }
}
