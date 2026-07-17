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
        if net.nodes.is_empty() { return Ok(()) }

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in logic network while doing set_threshold action"));
        };

        if let LogicNode::Input(input_node) = node
        && let Some(feat_id) = input_node.feat_id.clone() {
            let Some(range) = actions.thresholds.get(&feat_id) else {
                return Err(format!("Couldn't find threshold range at for feature ID {feat_id} while doing set_threshold action"))
            };
            input_node.threshold = Some(range.value_at(state.threshold_idx, actions.n_thresholds));
        }

        Ok(())
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
    use approx::assert_relative_eq;
    use hegel::TestCase;
    use hegel::generators::booleans;
    use mockall::predicate::always;
    use crate::actions::actions::tests::{gen_actions_state, gen_meta_actions, gen_thresholds};
    use crate::network::logic_net::tests::gen_logic_net;
    use crate::test_utils::{gen_text, gen_usize_with_max, gen_vec};

    fn sub_actions() -> Vec<Action> {
        vec![Action::NextFeat, Action::NextThreshold, Action::SelectNode]
    }

    fn new_input_node() -> InputNode {
        InputNode { threshold: None, feat_id: None, value: false }
    }

    fn new_gate_node() -> GateNode {
        GateNode { gate: None, in1_idx: None, in2_idx: None, value: false }
    }

    fn empty_net() -> LogicNet {
        LogicNet { nodes: Vec::new(), default_value: false }
    }

    #[hegel::composite]
    pub fn gen_logic_actions(tc: TestCase, feat_ids: Option<&[String]>, allow_recurrence: Option<bool>) -> LogicActions {
        let feat_order = match feat_ids {
            Some(ids) => ids.to_vec(),
            None => {
                let n_feats = tc.draw(gen_usize_with_max(4)) + 1;
                tc.draw(gen_vec(gen_text(), n_feats))
            }
        };

        let thresholds = tc.draw(gen_thresholds(&feat_order));
        let meta_actions = tc.draw(gen_meta_actions(&sub_actions()));
        let n_thresholds = tc.draw(gen_usize_with_max(9)) + 1;
        let n_gates = tc.draw(gen_usize_with_max(5)) + 1;
        let all_gates = [Gate::And, Gate::Or, Gate::Xor, Gate::Nand, Gate::Nor, Gate::Xnor];
        let allowed_gates = all_gates[0..n_gates].to_vec();
        let recurrence = allow_recurrence.unwrap_or_else(|| tc.draw(booleans()));

        LogicActions {
            meta_actions,
            thresholds,
            n_thresholds,
            feat_order,
            allow_recurrence: recurrence,
            allowed_gates
        }
    }

    #[hegel::composite]
    fn gen_state_for(tc: TestCase, actions: &LogicActions, n_nodes: usize) -> ActionsState {
        let n_feats = actions.feat_order.len();
        let n_gates = actions.allowed_gates.len();
        tc.draw(gen_actions_state(n_nodes, n_feats, actions.n_thresholds, n_gates))
    }

    #[hegel::test]
    fn test_do_next_feat(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let mut state = tc.draw(gen_state_for(&actions, 1));
        let feat_idx = state.feat_idx;

        LogicActionsDepsImpl.do_next_feat(&actions, &mut state);

        let advanced_idx = feat_idx + 1;
        let expected_idx = advanced_idx % actions.feat_order.len();
        assert_eq!(state.feat_idx, expected_idx);
    }

    #[hegel::test]
    fn test_do_next_threshold(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let mut state = tc.draw(gen_state_for(&actions, 1));
        let threshold_idx = state.threshold_idx;

        LogicActionsDepsImpl.do_next_threshold(&actions, &mut state);

        let advanced_idx = threshold_idx + 1;
        let expected_idx = advanced_idx % actions.n_thresholds;
        assert_eq!(state.threshold_idx, expected_idx);
    }

    #[hegel::test]
    fn test_do_next_node(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let net = tc.draw(gen_logic_net(Some(false), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let node_idx = state.node_idx;

        LogicActionsDepsImpl.do_next_node(&mut state, &net);

        let advanced_idx = node_idx + 1;
        let expected_idx = advanced_idx % net.nodes.len();
        assert_eq!(state.node_idx, expected_idx);
    }

    #[hegel::test]
    fn test_do_select_node(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let mut state = tc.draw(gen_state_for(&actions, 5));
        let node_idx = state.node_idx;

        LogicActionsDepsImpl.do_select_node(&mut state);

        assert_eq!(state.selected_idx, node_idx);
    }

    #[hegel::test]
    fn test_do_next_gate(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let mut state = tc.draw(gen_state_for(&actions, 1));
        let extra_idx = state.extra_idx;

        LogicActionsDepsImpl.do_next_gate(&actions, &mut state);

        let advanced_idx = extra_idx + 1;
        let expected_idx = advanced_idx % actions.allowed_gates.len();
        assert_eq!(state.extra_idx, expected_idx);
    }

    #[hegel::test]
    fn test_allow_connection(tc: TestCase) {
        let recurrent_actions = tc.draw(gen_logic_actions(None, Some(true)));
        let feedforward_actions = tc.draw(gen_logic_actions(None, Some(false)));
        let state = tc.draw(gen_state_for(&feedforward_actions, 5));

        assert!(LogicActionsDepsImpl.allow_connection(&recurrent_actions, &state));

        let feedforward_allowed = LogicActionsDepsImpl.allow_connection(&feedforward_actions, &state);
        assert_eq!(feedforward_allowed, state.selected_idx < state.node_idx);
    }

    #[hegel::test]
    fn test_do_set_feat(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let feat_ids = actions.feat_order.clone();
        let mut net = tc.draw(gen_logic_net(Some(false), Some(&feat_ids)));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        net.nodes[state.node_idx] = LogicNode::Input(new_input_node());

        LogicActionsDepsImpl.do_set_feat(&actions, &state, &mut net).unwrap();

        let feat_id = feat_ids[state.feat_idx].clone();
        let expected_input = InputNode { threshold: None, feat_id: Some(feat_id), value: false };
        assert_eq!(net.nodes[state.node_idx], LogicNode::Input(expected_input));

        let gate_node = new_gate_node();
        net.nodes[state.node_idx] = LogicNode::Gate(gate_node.clone());
        LogicActionsDepsImpl.do_set_feat(&actions, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], LogicNode::Gate(gate_node));

        let mut net_without_nodes = empty_net();
        let empty_result = LogicActionsDepsImpl.do_set_feat(&actions, &state, &mut net_without_nodes);
        assert!(empty_result.is_ok());

        state.feat_idx = feat_ids.len();
        let bad_feat_result = LogicActionsDepsImpl.do_set_feat(&actions, &state, &mut net);
        assert!(bad_feat_result.is_err());

        state.feat_idx = 0;
        state.node_idx = net.nodes.len();
        let bad_node_result = LogicActionsDepsImpl.do_set_feat(&actions, &state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_set_threshold(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let feat_ids = actions.feat_order.clone();
        let unknown_feat_id = tc.draw(gen_text());
        tc.assume(!feat_ids.contains(&unknown_feat_id));

        let mut net = tc.draw(gen_logic_net(Some(false), Some(&feat_ids)));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let feat_id = feat_ids[state.feat_idx].clone();
        let input_node = InputNode { threshold: None, feat_id: Some(feat_id.clone()), value: false };
        net.nodes[state.node_idx] = LogicNode::Input(input_node);

        LogicActionsDepsImpl.do_set_threshold(&actions, &state, &mut net).unwrap();

        let range = &actions.thresholds[&feat_id];
        let expected_threshold = range.value_at(state.threshold_idx, actions.n_thresholds);
        let LogicNode::Input(set_node) = &net.nodes[state.node_idx] else { panic!("expected an input node") };
        assert_relative_eq!(set_node.threshold.unwrap(), expected_threshold, epsilon = 1e-5);

        let featless_node = new_input_node();
        net.nodes[state.node_idx] = LogicNode::Input(featless_node.clone());
        LogicActionsDepsImpl.do_set_threshold(&actions, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], LogicNode::Input(featless_node));

        let unknown_node = InputNode { threshold: None, feat_id: Some(unknown_feat_id), value: false };
        net.nodes[state.node_idx] = LogicNode::Input(unknown_node);
        let unknown_result = LogicActionsDepsImpl.do_set_threshold(&actions, &state, &mut net);
        assert!(unknown_result.is_err());

        let mut net_without_nodes = empty_net();
        let empty_result = LogicActionsDepsImpl.do_set_threshold(&actions, &state, &mut net_without_nodes);
        assert!(empty_result.is_ok());

        state.node_idx = net.nodes.len();
        let bad_node_result = LogicActionsDepsImpl.do_set_threshold(&actions, &state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_set_gate(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let mut net = tc.draw(gen_logic_net(Some(false), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        net.nodes[state.node_idx] = LogicNode::Gate(new_gate_node());

        LogicActionsDepsImpl.do_set_gate(&actions, &state, &mut net).unwrap();

        let gate = actions.allowed_gates[state.extra_idx];
        let expected_gate_node = GateNode { gate: Some(gate), in1_idx: None, in2_idx: None, value: false };
        assert_eq!(net.nodes[state.node_idx], LogicNode::Gate(expected_gate_node));

        let input_node = new_input_node();
        net.nodes[state.node_idx] = LogicNode::Input(input_node.clone());
        LogicActionsDepsImpl.do_set_gate(&actions, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], LogicNode::Input(input_node));

        let mut net_without_nodes = empty_net();
        let empty_result = LogicActionsDepsImpl.do_set_gate(&actions, &state, &mut net_without_nodes);
        assert!(empty_result.is_ok());

        state.extra_idx = actions.allowed_gates.len();
        let bad_gate_result = LogicActionsDepsImpl.do_set_gate(&actions, &state, &mut net);
        assert!(bad_gate_result.is_err());

        state.extra_idx = 0;
        state.node_idx = net.nodes.len();
        let bad_node_result = LogicActionsDepsImpl.do_set_gate(&actions, &state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_new_input(tc: TestCase) {
        let mut net = tc.draw(gen_logic_net(None, None));
        let n_nodes = net.nodes.len();

        LogicActionsDepsImpl.do_new_input(&mut net);

        assert_eq!(net.nodes.len(), n_nodes + 1);
        assert_eq!(net.nodes[n_nodes], LogicNode::Input(new_input_node()));
    }

    #[hegel::test]
    fn test_do_new_gate(tc: TestCase) {
        let mut net = tc.draw(gen_logic_net(None, None));
        let n_nodes = net.nodes.len();

        LogicActionsDepsImpl.do_new_gate(&mut net);

        assert_eq!(net.nodes.len(), n_nodes + 1);
        assert_eq!(net.nodes[n_nodes], LogicNode::Gate(new_gate_node()));
    }

    #[hegel::test]
    fn test_do_set_in1_idx(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let mut net = tc.draw(gen_logic_net(Some(false), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        net.nodes[state.node_idx] = LogicNode::Gate(new_gate_node());

        let mut allowing_deps = MockLogicActionsDeps::new();
        let allowing_dep = allowing_deps.expect_allow_connection().times(1);
        let allowing_dep = allowing_dep.with(always(), always());
        allowing_dep.return_const(true);

        actions._do_set_in1_idx(&allowing_deps, &state, &mut net).unwrap();

        let connected_node = GateNode { gate: None, in1_idx: Some(state.selected_idx), in2_idx: None, value: false };
        assert_eq!(net.nodes[state.node_idx], LogicNode::Gate(connected_node));

        let gate_node = new_gate_node();
        net.nodes[state.node_idx] = LogicNode::Gate(gate_node.clone());

        let mut blocking_deps = MockLogicActionsDeps::new();
        let blocking_dep = blocking_deps.expect_allow_connection().times(1);
        let blocking_dep = blocking_dep.with(always(), always());
        blocking_dep.return_const(false);

        actions._do_set_in1_idx(&blocking_deps, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], LogicNode::Gate(gate_node));

        let input_node = new_input_node();
        net.nodes[state.node_idx] = LogicNode::Input(input_node.clone());

        let mut input_deps = MockLogicActionsDeps::new();
        let input_dep = input_deps.expect_allow_connection().times(1);
        let input_dep = input_dep.with(always(), always());
        input_dep.return_const(true);

        actions._do_set_in1_idx(&input_deps, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], LogicNode::Input(input_node));

        // No is_empty guard here, unlike every other handler: an empty net errors rather than no-ops.
        let mut missing_deps = MockLogicActionsDeps::new();
        missing_deps.expect_allow_connection().times(0);

        let mut net_without_nodes = empty_net();
        let empty_result = actions._do_set_in1_idx(&missing_deps, &state, &mut net_without_nodes);
        assert!(empty_result.is_err());

        state.node_idx = net.nodes.len();
        let bad_node_result = actions._do_set_in1_idx(&missing_deps, &state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_set_in2_idx(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let mut net = tc.draw(gen_logic_net(Some(false), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        net.nodes[state.node_idx] = LogicNode::Gate(new_gate_node());

        let mut allowing_deps = MockLogicActionsDeps::new();
        let allowing_dep = allowing_deps.expect_allow_connection().times(1);
        let allowing_dep = allowing_dep.with(always(), always());
        allowing_dep.return_const(true);

        actions._do_set_in2_idx(&allowing_deps, &state, &mut net).unwrap();

        let connected_node = GateNode { gate: None, in1_idx: None, in2_idx: Some(state.selected_idx), value: false };
        assert_eq!(net.nodes[state.node_idx], LogicNode::Gate(connected_node));

        let gate_node = new_gate_node();
        net.nodes[state.node_idx] = LogicNode::Gate(gate_node.clone());

        let mut blocking_deps = MockLogicActionsDeps::new();
        let blocking_dep = blocking_deps.expect_allow_connection().times(1);
        let blocking_dep = blocking_dep.with(always(), always());
        blocking_dep.return_const(false);

        actions._do_set_in2_idx(&blocking_deps, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], LogicNode::Gate(gate_node));

        let input_node = new_input_node();
        net.nodes[state.node_idx] = LogicNode::Input(input_node.clone());

        let mut input_deps = MockLogicActionsDeps::new();
        let input_dep = input_deps.expect_allow_connection().times(1);
        let input_dep = input_dep.with(always(), always());
        input_dep.return_const(true);

        actions._do_set_in2_idx(&input_deps, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], LogicNode::Input(input_node));

        let mut missing_deps = MockLogicActionsDeps::new();
        missing_deps.expect_allow_connection().times(0);

        let mut net_without_nodes = empty_net();
        let empty_result = actions._do_set_in2_idx(&missing_deps, &state, &mut net_without_nodes);
        assert!(empty_result.is_err());

        state.node_idx = net.nodes.len();
        let bad_node_result = actions._do_set_in2_idx(&missing_deps, &state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_meta_action(tc: TestCase) {
        let mut actions = tc.draw(gen_logic_actions(None, None));
        let label = tc.draw(gen_text());
        let unknown_label = tc.draw(gen_text());
        tc.assume(label != unknown_label);
        tc.assume(!actions.meta_actions.contains_key(&unknown_label));

        let n_feats = actions.feat_order.len();
        let two_next_feats = vec![Action::NextFeat, Action::NextFeat];
        actions.meta_actions.insert(label.clone(), two_next_feats);

        let mut net = tc.draw(gen_logic_net(Some(false), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let feat_idx = state.feat_idx;

        LogicActionsDepsImpl.do_meta_action(&actions, &mut net, &mut state, label);

        let advanced_idx = feat_idx + 2;
        let expected_idx = advanced_idx % n_feats;
        assert_eq!(state.feat_idx, expected_idx);

        LogicActionsDepsImpl.do_meta_action(&actions, &mut net, &mut state, unknown_label);
        assert_eq!(state.feat_idx, expected_idx);
    }

    #[hegel::test]
    fn test_do_action(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let label = tc.draw(gen_text());
        let mut net = tc.draw(gen_logic_net(Some(false), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

        let mut mock_deps = MockLogicActionsDeps::new();

        let meta_action_dep = mock_deps.expect_do_meta_action().times(1);
        meta_action_dep.return_const(());

        let next_feat_dep = mock_deps.expect_do_next_feat().times(1);
        next_feat_dep.return_const(());

        let next_threshold_dep = mock_deps.expect_do_next_threshold().times(1);
        next_threshold_dep.return_const(());

        let next_node_dep = mock_deps.expect_do_next_node().times(1);
        next_node_dep.return_const(());

        let select_node_dep = mock_deps.expect_do_select_node().times(1);
        select_node_dep.return_const(());

        let next_gate_dep = mock_deps.expect_do_next_gate().times(1);
        next_gate_dep.return_const(());

        let new_input_dep = mock_deps.expect_do_new_input().times(1);
        new_input_dep.return_const(());

        let new_gate_dep = mock_deps.expect_do_new_gate().times(1);
        new_gate_dep.return_const(());

        let set_feat_dep = mock_deps.expect_do_set_feat().times(1);
        set_feat_dep.returning(|_, _, _| Ok(()));

        let set_threshold_dep = mock_deps.expect_do_set_threshold().times(1);
        set_threshold_dep.returning(|_, _, _| Ok(()));

        let set_gate_dep = mock_deps.expect_do_set_gate().times(1);
        set_gate_dep.returning(|_, _, _| Ok(()));

        let set_in1_idx_dep = mock_deps.expect_do_set_in1_idx().times(1);
        set_in1_idx_dep.returning(|_, _, _| Ok(()));

        let set_in2_idx_dep = mock_deps.expect_do_set_in2_idx().times(1);
        set_in2_idx_dep.returning(|_, _, _| Ok(()));

        let meta_action = Action::MetaAction(label);
        let action_seq = vec![meta_action, Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::NextGate, Action::SetFeat, Action::SetThreshold, Action::SetGate, Action::SetIn1Idx, Action::SetIn2Idx, Action::NewInput, Action::NewGate];

        for action in action_seq {
            actions._do_action(&mock_deps, &mut net, &mut state, action);
        }
    }

    #[hegel::test]
    fn test_do_action_ignores_decision_actions(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));
        let mut net = tc.draw(gen_logic_net(Some(false), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let net_before = net.clone();
        let feat_idx = state.feat_idx;

        // A bare mock panics on any unexpected call, so this asserts the `_ => {}` arm dispatches nothing.
        let mock_deps = MockLogicActionsDeps::new();
        let action_seq = vec![Action::SetTrueIdx, Action::SetFalseIdx, Action::SetRefIdx, Action::NewBranch, Action::NewRef];

        for action in action_seq {
            actions._do_action(&mock_deps, &mut net, &mut state, action);
        }

        assert_eq!(net, net_before);
        assert_eq!(state.feat_idx, feat_idx);
    }

    #[hegel::test]
    fn test_actions_list(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));

        let list = actions.actions_list();

        let builtins = vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::NextGate, Action::SetFeat, Action::SetThreshold, Action::SetGate, Action::SetIn1Idx, Action::SetIn2Idx, Action::NewInput, Action::NewGate];
        let n_builtins = builtins.len();
        assert_eq!(list[0..n_builtins], builtins);
        assert_eq!(list.len(), n_builtins + actions.meta_actions.len());

        for label in actions.meta_actions.keys() {
            let meta_action = Action::MetaAction(label.clone());
            assert!(list.contains(&meta_action));
        }
    }

    #[hegel::test]
    fn test_to_json(tc: TestCase) {
        let actions = tc.draw(gen_logic_actions(None, None));

        let value = actions.to_json();

        assert_eq!(value["type"], "logic");
        assert_eq!(value["meta_actions"], meta_actions_json(&actions.meta_actions));
        assert_eq!(value["thresholds"], thresholds_json(&actions.thresholds, &actions.feat_order));
        assert_eq!(value["feat_order"], json!(actions.feat_order));
        assert_eq!(value["n_thresholds"], json!(actions.n_thresholds));
        assert_eq!(value["allow_recurrence"], json!(actions.allow_recurrence));
        assert_eq!(value["allowed_gates"], json!(actions.allowed_gates));
    }
}