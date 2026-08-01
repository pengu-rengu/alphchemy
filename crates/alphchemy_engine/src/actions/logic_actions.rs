use std::collections::HashMap;
use serde_json::{json, Value};
#[cfg(test)]
use mockall::automock;

use crate::actions::actions::{Action, Actions, ActionsState, ThresholdRange, meta_actions_json, thresholds_json};
use crate::network::logic_net::{LogicNet, LogicNode, Gate, InputNode, GateNode};

#[derive(Clone, Debug)]
pub struct LogicActions {
    pub meta_actions: HashMap<String, Vec<Action>>,
    pub thresholds: HashMap<String, ThresholdRange>,
    pub n_thresholds: usize,
    pub feat_order: Vec<String>,
    pub allow_recurrence: bool,
    pub allowed_gates: Vec<Gate>
}

#[cfg_attr(test, automock)]
trait LogicActionsDeps {
    fn value_at(&self, range: &ThresholdRange, idx: usize, n_thresholds: usize) -> f64 {
        range.value_at(idx, n_thresholds)
    }

    fn do_meta_action(&self, actions: &LogicActions, net: &mut LogicNet, state: &mut ActionsState, label: String) {
        if let Some(sub_actions) = actions.meta_actions.get(&label) {
            for sub_action in sub_actions {
                actions.do_action(net, state, sub_action.clone());
            }
        }
    }

    fn do_next_feat(&self, actions: &LogicActions, state: &mut ActionsState) {
        state.next_feat(actions.feat_order.len());
    }

    fn do_next_threshold(&self, actions: &LogicActions, state: &mut ActionsState) {
        state.next_threshold(actions.n_thresholds);
    }

    fn do_next_node(&self, state: &mut ActionsState, net: &LogicNet) {
        state.next_node(net.nodes.len());
    }

    fn do_select_node(&self, state: &mut ActionsState) {
        state.select_node();
    }

    fn do_next_gate(&self, actions: &LogicActions, state: &mut ActionsState) {
        state.extra_idx += 1;
        if state.extra_idx >= actions.allowed_gates.len() {
            state.extra_idx = 0;
        }
    }

    fn do_set_feat(&self, actions: &LogicActions, state: &ActionsState, net: &mut LogicNet) -> Result<(), String> {
        if net.nodes.is_empty() { return Ok(()) }

        let feat_idx = state.feat_idx;
        let Some(feat_id) = actions.feat_order.get(feat_idx) else {
            return Err(format!("Couldn't find feature ID at index {feat_idx} in feat_order while doing set_feat action"))
        };

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in logic network while doing set_feat action"))
        };

        if let LogicNode::Input(input_node) = node {
            input_node.feat_id = Some(feat_id.clone());
            
        }
        Ok(())
    }

    fn do_set_threshold(&self, actions: &LogicActions, state: &ActionsState, net: &mut LogicNet) -> Result<(), String> {
        actions._do_set_threshold(&LogicActionsDepsImpl, state, net)
    }

    fn do_set_gate(&self, actions: &LogicActions, state: &ActionsState, net: &mut LogicNet) -> Result<(), String> {
        if net.nodes.is_empty() { return Ok(()) }

        let extra_idx = state.extra_idx;
        let Some(&gate) = actions.allowed_gates.get(state.extra_idx) else {
            return Err(format!("Couldn't find gate at index {extra_idx} in allowed_gates while doing set_gate action"))
        };

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in logic network while doing set_gate action"))
        };

        if let LogicNode::Gate(gate_node) = node {
            gate_node.gate = Some(gate);
        }

        Ok(())
    }

    fn allow_connection(&self, actions: &LogicActions, state: &ActionsState) -> bool {
        actions.allow_recurrence || state.selected_idx < state.node_idx
    }

    fn do_set_in1_idx(&self, actions: &LogicActions, state: &ActionsState, net: &mut LogicNet) -> Result<(), String> {
        actions._do_set_in1_idx(&LogicActionsDepsImpl, state, net)
    }

    fn do_set_in2_idx(&self, actions: &LogicActions, state: &ActionsState, net: &mut LogicNet) -> Result<(), String> {
        actions._do_set_in2_idx(&LogicActionsDepsImpl, state, net)
    }

    fn do_new_input(&self, net: &mut LogicNet) {
        let input_node = InputNode {
            threshold: None,
            feat_id: None,
            value: false
        };
        let new_node = LogicNode::Input(input_node);
        net.nodes.push(new_node);
    }

    fn do_new_gate(&self, net: &mut LogicNet) {
        let gate_node = GateNode {
            gate: None,
            in1_idx: None,
            in2_idx: None,
            value: false
        };
        let new_node = LogicNode::Gate(gate_node);
        net.nodes.push(new_node);
    }
}

struct LogicActionsDepsImpl;
impl LogicActionsDeps for LogicActionsDepsImpl {}

impl LogicActions {
    fn _do_set_in1_idx<T>(&self, deps: &T, state: &ActionsState, net: &mut LogicNet) -> Result<(), String> where T: LogicActionsDeps {
        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in logic network while doing set_in1_idx action"))
        };

        if deps.allow_connection(self, state) && let LogicNode::Gate(gate_node) = node {
            gate_node.in1_idx = Some(state.selected_idx);
        }

        Ok(())
    }

    fn _do_set_in2_idx<T>(&self, deps: &T, state: &ActionsState, net: &mut LogicNet) -> Result<(), String> where T: LogicActionsDeps {
        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in logic network while doing set_in2 action"))
        };

        if deps.allow_connection(self, state) && let LogicNode::Gate(gate_node) = node {
            gate_node.in2_idx = Some(state.selected_idx)
        }
        Ok(())
    }

    fn _do_set_threshold<T>(&self, deps: &T, state: &ActionsState, net: &mut LogicNet) -> Result<(), String> where T: LogicActionsDeps {
        if net.nodes.is_empty() { return Ok(()) }

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in logic network while doing set_threshold action"));
        };

        if let LogicNode::Input(input_node) = node
        && let Some(feat_id) = input_node.feat_id.clone() {
            let Some(range) = self.thresholds.get(&feat_id) else {
                return Err(format!("Couldn't find threshold range at for feature ID {feat_id} while doing set_threshold action"))
            };
            input_node.threshold = Some(deps.value_at(range, state.threshold_idx, self.n_thresholds));
        }

        Ok(())
    }

    fn _do_action<T>(&self, deps: &T, net: &mut LogicNet, state: &mut ActionsState, action: Action) where T: LogicActionsDeps {
        // TODO: remove unwrap, propagate errors
        match action {
            Action::MetaAction(label) => deps.do_meta_action(self, net, state, label),
            Action::NextFeat => deps.do_next_feat(self, state),
            Action::NextThreshold => deps.do_next_threshold(self, state),
            Action::NextNode => deps.do_next_node(state, net),
            Action::SelectNode => deps.do_select_node(state),
            Action::NextGate => deps.do_next_gate(self, state),
            Action::SetFeat => deps.do_set_feat(self, state, net).unwrap(), 
            Action::SetThreshold => deps.do_set_threshold(self, state, net).unwrap(),
            Action::SetGate => deps.do_set_gate(self, state, net).unwrap(),
            Action::SetIn1Idx => deps.do_set_in1_idx(self, state, net).unwrap(),
            Action::SetIn2Idx => deps.do_set_in2_idx(self, state, net).unwrap(),
            Action::NewInput => deps.do_new_input(net),
            Action::NewGate => deps.do_new_gate(net),
            _ => {}
        }
    }
}

impl Actions<LogicNet> for LogicActions {
    fn to_json(&self) -> Value {
        json!({
            "type": "logic",
            "meta_actions": meta_actions_json(&self.meta_actions),
            "thresholds": thresholds_json(&self.thresholds, &self.feat_order),
            "feat_order": self.feat_order,
            "n_thresholds": self.n_thresholds,
            "allow_recurrence": self.allow_recurrence,
            "allowed_gates": self.allowed_gates
        })
    }

    fn actions_list(&self) -> Vec<Action> {
        let mut list = vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::NextGate, Action::SetFeat, Action::SetThreshold, Action::SetGate, Action::SetIn1Idx, Action::SetIn2Idx, Action::NewInput, Action::NewGate];

        for label in self.meta_actions.keys() {
            list.push(Action::MetaAction(label.clone()));
        }

        list
    }

    fn do_action(&self, net: &mut LogicNet, state: &mut ActionsState, action: Action) {
        self._do_action(&LogicActionsDepsImpl, net, state, action);
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use crate::actions::actions::tests::{gen_actions_state, gen_meta_actions, gen_thresholds};
    use crate::network::logic_net::tests::{gen_gate_node, gen_input_node, gen_logic_net};
    use alphchemy_test_utils::{gen_text, gen_usize_between, gen_usize_with_max, gen_usize_with_min, gen_vec, gen_f64};
    use hegel::generators::{booleans, sampled_from};
    use hegel::TestCase;

    #[hegel::composite]
    fn gen_sub_actions(tc: TestCase) -> Vec<Action> {
        let seq_len = tc.draw(gen_usize_with_max(4)) + 1;
        let gen_action = sampled_from(vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::NextGate]);
        tc.draw(gen_vec(gen_action, seq_len))
    }

    #[hegel::composite]
    pub fn gen_logic_actions(tc: TestCase, feat_ids: Option<&[String]>, allow_recurrence: Option<bool>) -> LogicActions {
        let feat_order = feat_ids.map(|ids| ids.to_vec()).unwrap_or_else(|| {
            let n_feats = tc.draw(gen_usize_between(1, 4));
            tc.draw(gen_vec(gen_text(), n_feats))
        });

        let thresholds = tc.draw(gen_thresholds(&feat_order));
        let sub_actions = tc.draw(gen_sub_actions());

        let meta_actions = tc.draw(gen_meta_actions(&sub_actions));
        let n_thresholds = tc.draw(gen_usize_between(1, 10));

        let allowed_gates = [Gate::And, Gate::Or, Gate::Xor, Gate::Nand, Gate::Nor, Gate::Xnor][0..tc.draw(gen_usize_between(1, 6))].to_vec();
        let recurrence = allow_recurrence.unwrap_or_else(|| tc.draw(booleans()));

        LogicActions { meta_actions, thresholds, n_thresholds, feat_order, allow_recurrence: recurrence,  allowed_gates }
    }

    #[hegel::composite]
    fn gen_state_for(tc: TestCase, actions: &LogicActions, n_nodes: usize) -> ActionsState {
        tc.draw(gen_actions_state(n_nodes, actions.feat_order.len(), actions.n_thresholds, actions.allowed_gates.len()))
    }

    mod do_set_feat_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            new_feat_id: Option<String>,
            prev_feat_id: Option<String>,
            feat_id: Option<String>,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_gate_node: Option<bool>, draw_invalid: bool) -> TestContext {
            let actions = tc.draw(gen_logic_actions(None, None));
            let mut net = tc.draw(gen_logic_net(Some(false), Some(&actions.feat_order)));
            let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

            let draw_invalid_feat_idx = if draw_invalid { tc.draw(booleans()) } else { false };
            let draw_invalid_node_idx = if draw_invalid {
                if draw_invalid_feat_idx { tc.draw(booleans()) } else { true }
            } else { false };

            if draw_invalid_feat_idx {
                state.feat_idx = tc.draw(gen_usize_with_min(actions.feat_order.len()));
            }
            if draw_invalid_node_idx {
                state.node_idx = tc.draw(gen_usize_with_min(net.nodes.len()));
            }

            let mut prev_feat_id = None;
            let node_idx = state.node_idx;
            let valid_node_idx = !draw_invalid_node_idx;
            if valid_node_idx {
                net.nodes[node_idx]  = if draw_gate_node.unwrap_or_else(|| tc.draw(booleans())) {
                    let gate_node = tc.draw(gen_gate_node(net.nodes.len(), None, None, None));
                    LogicNode::Gate(gate_node.clone())
                } else {
                    let input_node = tc.draw(gen_input_node(None, None, None));
                    prev_feat_id = input_node.feat_id.clone();
                    LogicNode::Input(input_node)
                };
            }

            let new_feat_id = if draw_invalid_feat_idx { None } else { Some(actions.feat_order[state.feat_idx].clone()) };

            let result = LogicActionsDepsImpl.do_set_feat(&actions, &state, &mut net);
            let feat_id = if valid_node_idx && let LogicNode::Input(input_node) = &net.nodes[node_idx] { input_node.feat_id.clone() } else { None };

            TestContext { new_feat_id, prev_feat_id, feat_id, result }
        }

        #[hegel::test]
        fn test_do_set_feat(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(false), false));
            assert_eq!(ctx.feat_id, ctx.new_feat_id);
        }

        #[hegel::test]
        fn test_do_set_feat_gate(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(true), false));
            assert_eq!(ctx.feat_id, ctx.prev_feat_id);
        }

        #[hegel::test]
        fn test_do_set_feat_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(None, true));
            assert!(ctx.result.is_err());
        }
    }

    mod do_set_threshold_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            new_threshold: f64,
            prev_threshold: Option<f64>,
            threshold: Option<f64>,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, maybe_draw_gate_or_no_feat: Option<bool>, draw_invalid: bool) -> TestContext {
            let actions = tc.draw(gen_logic_actions(None, None));
            let mut net = tc.draw(gen_logic_net(Some(false), Some(&actions.feat_order)));
            let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

            let draw_invalid_node_idx = if draw_invalid { tc.draw(booleans()) } else { false };
            let draw_invalid_feat_id = if draw_invalid { !draw_invalid_node_idx } else { false };

            if draw_invalid_node_idx {
                state.node_idx = tc.draw(gen_usize_with_min(net.nodes.len()));
            }

            let draw_gate_or_no_feat = !draw_invalid_feat_id && maybe_draw_gate_or_no_feat.unwrap_or_else(|| tc.draw(booleans()));
            let draw_gate_node = if draw_gate_or_no_feat { tc.draw(booleans()) } else { false };
            let draw_no_feat_id = if draw_gate_or_no_feat { !draw_gate_node } else { false };

            let mut prev_threshold = None;
            let node_idx = state.node_idx;
            let valid_node_idx = !draw_invalid_node_idx;
            if valid_node_idx {
                net.nodes[node_idx] = if draw_gate_node {
                    let gate_node = tc.draw(gen_gate_node(net.nodes.len(), None, None, None));
                    LogicNode::Gate(gate_node.clone())
                } else {
                    let feat_ids = vec![if draw_invalid_feat_id {
                        let invalid_feat_id = tc.draw(gen_text());
                        tc.assume(!actions.thresholds.contains_key(&invalid_feat_id));
                        invalid_feat_id
                    } else {
                        tc.draw(sampled_from(actions.feat_order.clone()))
                    }];
                    let input_node = tc.draw(gen_input_node(None, Some(&feat_ids), Some(!draw_no_feat_id)));
                    prev_threshold = input_node.threshold.clone();
                    LogicNode::Input(input_node)
                };
            }

            let new_threshold = tc.draw(gen_f64());

            let mut mock_deps = MockLogicActionsDeps::new();

            let value_at_count = usize::from(!draw_invalid && !draw_gate_or_no_feat);
            mock_deps.expect_value_at()
                .times(value_at_count)
                .return_const(new_threshold);

            let result = actions._do_set_threshold(&mock_deps, &state, &mut net);
            let threshold = if valid_node_idx && let LogicNode::Input(input_node) = &net.nodes[node_idx] { input_node.threshold.clone() } else { None };

            TestContext { new_threshold, prev_threshold, threshold, result }
        }

        #[hegel::test]
        fn test_do_set_threshold(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(false), false));
            assert_eq!(ctx.threshold, Some(ctx.new_threshold));
        }

        #[hegel::test]
        fn test_do_set_threshold_gate_or_no_feat(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(true), false));
            assert_eq!(ctx.threshold, ctx.prev_threshold);
        }

        #[hegel::test]
        fn test_do_set_threshold_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(None, true));
            assert!(ctx.result.is_err());
        }
    }

    mod do_set_gate_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            new_gate: Option<Gate>,
            prev_gate: Option<Gate>,
            gate: Option<Gate>,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_input_node: Option<bool>, draw_invalid: bool) -> TestContext {
            let actions = tc.draw(gen_logic_actions(None, None));
            let mut net = tc.draw(gen_logic_net(Some(false), Some(&actions.feat_order)));
            let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

            let draw_invalid_gate_idx = if draw_invalid { tc.draw(booleans()) } else { false };
            let draw_invalid_node_idx = if draw_invalid { !draw_invalid_gate_idx } else { false };

            if draw_invalid_gate_idx {
                state.extra_idx = tc.draw(gen_usize_with_min(actions.allowed_gates.len()));
            }
            if draw_invalid_node_idx {
                state.node_idx = tc.draw(gen_usize_with_min(net.nodes.len()));
            }

            let mut prev_gate = None;
            let node_idx = state.node_idx;
            let valid_node_idx = !draw_invalid_node_idx;
            if valid_node_idx {
                net.nodes[node_idx] = if draw_input_node.unwrap_or_else(|| tc.draw(booleans())) {
                    let input_node = tc.draw(gen_input_node(None, None, None));
                    LogicNode::Input(input_node)
                } else {
                    let gate_node = tc.draw(gen_gate_node(net.nodes.len(), None, None, None));
                    prev_gate = gate_node.gate;
                    LogicNode::Gate(gate_node)
                };
            }

            let new_gate = if draw_invalid_gate_idx { None } else { Some(actions.allowed_gates[state.extra_idx]) };

            let result = LogicActionsDepsImpl.do_set_gate(&actions, &state, &mut net);
            let gate = if valid_node_idx && let LogicNode::Gate(gate_node) = &net.nodes[node_idx] { gate_node.gate } else { None };

            TestContext { new_gate, prev_gate, gate, result }
        }

        #[hegel::test]
        fn test_do_set_gate(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(false), false));
            assert_eq!(ctx.gate, ctx.new_gate);
        }

        #[hegel::test]
        fn test_do_set_gate_input(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(true), false));
            assert_eq!(ctx.gate, ctx.prev_gate);
        }

        #[hegel::test]
        fn test_do_set_gate_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(None, true));
            assert!(ctx.result.is_err());
        }
    }

    #[hegel::test]
    fn test_do_new_input(tc: TestCase) {
        let mut net = tc.draw(gen_logic_net(None, None));
        let n_nodes = net.nodes.len();

        LogicActionsDepsImpl.do_new_input(&mut net);

        assert_eq!(net.nodes.len(), n_nodes + 1);
        let LogicNode::Input(new_node) = &net.nodes[n_nodes] else {
            panic!("expected an input node")
        };
        assert_eq!(new_node.threshold, None);
        assert_eq!(new_node.feat_id, None);
        assert!(!new_node.value);
    }

    #[hegel::test]
    fn test_do_new_gate(tc: TestCase) {
        let mut net = tc.draw(gen_logic_net(None, None));
        let n_nodes = net.nodes.len();

        LogicActionsDepsImpl.do_new_gate(&mut net);

        assert_eq!(net.nodes.len(), n_nodes + 1);
        let LogicNode::Gate(new_node) = &net.nodes[n_nodes] else {
            panic!("expected a gate node")
        };
        assert_eq!(new_node.gate, None);
        assert_eq!(new_node.in1_idx, None);
        assert_eq!(new_node.in2_idx, None);
        assert!(!new_node.value);
    }

    mod do_action_tests {

    }
}
