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
    use crate::actions::actions::tests::{gen_actions_state, gen_meta_actions, gen_thresholds};
    use crate::network::logic_net::tests::{gen_gate_node, gen_input_node, gen_logic_net};
    use crate::test_utils::{gen_text, gen_usize_with_max, gen_usize_with_min, gen_vec};
    use approx::assert_relative_eq;
    use hegel::generators::{booleans, sampled_from};
    use hegel::TestCase;

    #[hegel::composite]
    fn gen_sub_actions(tc: TestCase) -> Vec<Action> {
        let candidates = vec![
            Action::NextFeat,
            Action::NextThreshold,
            Action::NextNode,
            Action::SelectNode,
            Action::NextGate
        ];
        let seq_len = tc.draw(gen_usize_with_max(4)) + 1;
        tc.draw(gen_vec(sampled_from(candidates), seq_len))
    }

    #[hegel::composite]
    pub fn gen_logic_actions(
        tc: TestCase,
        feat_ids: Option<&[String]>,
        allow_recurrence: Option<bool>
    ) -> LogicActions {
        let feat_order = match feat_ids {
            Some(ids) => ids.to_vec(),
            None => {
                let n_feats = tc.draw(gen_usize_with_max(4)) + 1;
                tc.draw(gen_vec(gen_text(), n_feats))
            }
        };

        let thresholds = tc.draw(gen_thresholds(&feat_order));
        let sub_actions = tc.draw(gen_sub_actions());
        let meta_actions = tc.draw(gen_meta_actions(&sub_actions));
        let n_thresholds = tc.draw(gen_usize_with_max(9)) + 1;
        let n_gates = tc.draw(gen_usize_with_max(5)) + 1;
        let all_gates = [
            Gate::And,
            Gate::Or,
            Gate::Xor,
            Gate::Nand,
            Gate::Nor,
            Gate::Xnor
        ];
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
    fn gen_state_for(
        tc: TestCase,
        actions: &LogicActions,
        maybe_n_nodes: Option<usize>
    ) -> ActionsState {
        let n_nodes = maybe_n_nodes.unwrap_or_else(|| tc.draw(gen_usize_with_min(1)));
        tc.draw(gen_actions_state(
            n_nodes,
            actions.feat_order.len(),
            actions.n_thresholds,
            actions.allowed_gates.len()
        ))
    }

    #[derive(Debug)]
    struct TestContext {
        actions: LogicActions,
        net: LogicNet,
        state: ActionsState
    }

    #[hegel::composite]
    fn gen_context(tc: TestCase) -> TestContext {
        let actions = tc.draw(gen_logic_actions(None, None));
        let feat_ids = actions.feat_order.clone();
        let net = tc.draw(gen_logic_net(Some(false), Some(&feat_ids)));
        let state = tc.draw(gen_state_for(&actions, Some(net.nodes.len())));

        TestContext {
            actions,
            net,
            state
        }
    }

    mod do_next_feat_tests {
        use super::*;
        #[hegel::test]
        fn test_do_next_feat(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, None));
            let mut state = tc.draw(gen_state_for(&actions, None));
            let advanced_idx = state.feat_idx + 1;

            LogicActionsDepsImpl.do_next_feat(&actions, &mut state);

            assert_eq!(state.feat_idx, advanced_idx % actions.feat_order.len());
        }
    }

    mod do_next_threshold_tests {
        use super::*;
        #[hegel::test]
        fn test_do_next_threshold(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, None));
            let mut state = tc.draw(gen_state_for(&actions, None));

            let advanced_idx = state.threshold_idx + 1;

            LogicActionsDepsImpl.do_next_threshold(&actions, &mut state);

            assert_eq!(state.threshold_idx, advanced_idx % actions.n_thresholds);
        }
    }

    mod do_next_node_tests {
        use super::*;
        #[hegel::test]
        fn test_do_next_node(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, None));
            let net = tc.draw(gen_logic_net(Some(false), None));
            let mut state = tc.draw(gen_state_for(&actions, Some(net.nodes.len())));
            let advanced_idx = state.node_idx + 1;

            LogicActionsDepsImpl.do_next_node(&mut state, &net);

            assert_eq!(state.node_idx, advanced_idx % net.nodes.len());
        }
    }

    mod do_select_node_tests {
        use super::*;
        #[hegel::test]
        fn test_do_select_node(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, None));
            let mut state = tc.draw(gen_state_for(&actions, None));

            LogicActionsDepsImpl.do_select_node(&mut state);

            assert_eq!(state.selected_idx, state.node_idx);
        }
    }

    mod do_next_gate_tests {
        use super::*;
        #[hegel::test]
        fn test_do_next_gate(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, None));
            let mut state = tc.draw(gen_state_for(&actions, None));
            let advanced_idx = state.extra_idx + 1;

            LogicActionsDepsImpl.do_next_gate(&actions, &mut state);

            assert_eq!(state.extra_idx, advanced_idx % actions.allowed_gates.len());
        }
    }

    mod allow_connection_tests {
        use super::*;

        #[hegel::test]
        fn test_allow_connection_recurrence(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, Some(true)));
            let state = tc.draw(gen_state_for(&actions, None));
            let allowed = LogicActionsDepsImpl.allow_connection(&actions, &state);
            assert!(allowed);
        }

        #[hegel::test]
        fn test_allow_connection_feedforward(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, Some(false)));
            let state = tc.draw(gen_state_for(&actions, None));
            let allowed = LogicActionsDepsImpl.allow_connection(&actions, &state);
            assert_eq!(allowed, state.selected_idx < state.node_idx);
        }
    }

    mod do_set_feat_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let input = tc.draw(gen_input_node(None, None, None));
            let feat_id = context.actions.feat_order[context.state.feat_idx].clone();
            context.net.nodes[context.state.node_idx] = LogicNode::Input(input.clone());
            LogicActionsDepsImpl
                .do_set_feat(&context.actions, &context.state, &mut context.net)
                .unwrap();
            let expected = InputNode {
                threshold: input.threshold,
                feat_id: Some(feat_id),
                value: input.value
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Input(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_feat_gate(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let gate = tc.draw(gen_gate_node(context.net.nodes.len(), None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Gate(gate.clone());
            LogicActionsDepsImpl
                .do_set_feat(&context.actions, &context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Gate(gate)
            );
        }

        #[hegel::test]
        fn test_do_set_feat_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = tc.draw(gen_logic_net(Some(true), None));
            let result =
                LogicActionsDepsImpl.do_set_feat(&context.actions, &context.state, &mut net);
            assert!(result.is_ok());
        }

        #[hegel::test]
        fn test_do_set_feat_missing_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.feat_idx = context.actions.feat_order.len();
            let result = LogicActionsDepsImpl.do_set_feat(
                &context.actions,
                &context.state,
                &mut context.net
            );
            assert!(result.is_err());
        }

        #[hegel::test]
        fn test_do_set_feat_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let result = LogicActionsDepsImpl.do_set_feat(
                &context.actions,
                &context.state,
                &mut context.net
            );
            assert!(result.is_err());
        }
    }

    mod do_set_threshold_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_threshold(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let feat_id = context.actions.feat_order[context.state.feat_idx].clone();
            let input = InputNode {
                threshold: None,
                feat_id: Some(feat_id.clone()),
                value: false
            };
            context.net.nodes[context.state.node_idx] = LogicNode::Input(input);
            LogicActionsDepsImpl
                .do_set_threshold(&context.actions, &context.state, &mut context.net)
                .unwrap();
            let range = &context.actions.thresholds[&feat_id];
            let expected =
                range.value_at(context.state.threshold_idx, context.actions.n_thresholds);
            let LogicNode::Input(node) = &context.net.nodes[context.state.node_idx] else {
                panic!("expected an input node")
            };
            assert_relative_eq!(node.threshold.unwrap(), expected, epsilon = 1e-5);
        }

        #[hegel::test]
        fn test_do_set_threshold_no_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let input = tc.draw(gen_input_node(None, None, Some(false)));
            context.net.nodes[context.state.node_idx] = LogicNode::Input(input.clone());
            LogicActionsDepsImpl
                .do_set_threshold(&context.actions, &context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Input(input)
            );
        }

        #[hegel::test]
        fn test_do_set_threshold_unknown_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let feat_id = tc.draw(gen_text());
            tc.assume(!context.actions.feat_order.contains(&feat_id));
            let input = InputNode {
                threshold: None,
                feat_id: Some(feat_id),
                value: false
            };
            context.net.nodes[context.state.node_idx] = LogicNode::Input(input);
            let result = LogicActionsDepsImpl.do_set_threshold(
                &context.actions,
                &context.state,
                &mut context.net
            );
            assert!(result.is_err());
        }

        #[hegel::test]
        fn test_do_set_threshold_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = tc.draw(gen_logic_net(Some(true), None));
            let result =
                LogicActionsDepsImpl.do_set_threshold(&context.actions, &context.state, &mut net);
            assert!(result.is_ok());
        }

        #[hegel::test]
        fn test_do_set_threshold_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let result = LogicActionsDepsImpl.do_set_threshold(
                &context.actions,
                &context.state,
                &mut context.net
            );
            assert!(result.is_err());
        }
    }

    mod do_set_gate_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_gate(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let gate = tc.draw(gen_gate_node(context.net.nodes.len(), None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Gate(gate.clone());
            LogicActionsDepsImpl
                .do_set_gate(&context.actions, &context.state, &mut context.net)
                .unwrap();
            let expected_gate = context.actions.allowed_gates[context.state.extra_idx];
            let expected = GateNode {
                gate: Some(expected_gate),
                in1_idx: gate.in1_idx,
                in2_idx: gate.in2_idx,
                value: gate.value
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Gate(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_gate_input(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let input = tc.draw(gen_input_node(None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Input(input.clone());
            LogicActionsDepsImpl
                .do_set_gate(&context.actions, &context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Input(input)
            );
        }

        #[hegel::test]
        fn test_do_set_gate_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = tc.draw(gen_logic_net(Some(true), None));
            let result =
                LogicActionsDepsImpl.do_set_gate(&context.actions, &context.state, &mut net);
            assert!(result.is_ok());
        }

        #[hegel::test]
        fn test_do_set_gate_missing_gate(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.extra_idx = context.actions.allowed_gates.len();
            let result = LogicActionsDepsImpl.do_set_gate(
                &context.actions,
                &context.state,
                &mut context.net
            );
            assert!(result.is_err());
        }

        #[hegel::test]
        fn test_do_set_gate_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let result = LogicActionsDepsImpl.do_set_gate(
                &context.actions,
                &context.state,
                &mut context.net
            );
            assert!(result.is_err());
        }
    }

    mod do_new_input_tests {
        use super::*;
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
    }

    mod do_new_gate_tests {
        use super::*;
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
    }

    mod do_set_in1_idx_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_in1_idx(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let gate = tc.draw(gen_gate_node(context.net.nodes.len(), None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Gate(gate.clone());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_allow_connection()
                .times(1)
                .return_const(true);
            context
                .actions
                ._do_set_in1_idx(&mock_deps, &context.state, &mut context.net)
                .unwrap();
            let expected = GateNode {
                gate: gate.gate,
                in1_idx: Some(context.state.selected_idx),
                in2_idx: gate.in2_idx,
                value: gate.value
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Gate(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_in1_idx_blocked(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let gate = tc.draw(gen_gate_node(context.net.nodes.len(), None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Gate(gate.clone());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_allow_connection()
                .times(1)
                .return_const(false);
            context
                .actions
                ._do_set_in1_idx(&mock_deps, &context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Gate(gate)
            );
        }

        #[hegel::test]
        fn test_do_set_in1_idx_input(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let input = tc.draw(gen_input_node(None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Input(input.clone());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_allow_connection()
                .times(1)
                .return_const(true);
            context
                .actions
                ._do_set_in1_idx(&mock_deps, &context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Input(input)
            );
        }

        #[hegel::test]
        fn test_do_set_in1_idx_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = tc.draw(gen_logic_net(Some(true), None));
            let mock_deps = MockLogicActionsDeps::new();
            let result = context
                .actions
                ._do_set_in1_idx(&mock_deps, &context.state, &mut net);
            assert!(result.is_err());
        }

        #[hegel::test]
        fn test_do_set_in1_idx_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let mock_deps = MockLogicActionsDeps::new();
            let result =
                context
                    .actions
                    ._do_set_in1_idx(&mock_deps, &context.state, &mut context.net);
            assert!(result.is_err());
        }
    }

    mod do_set_in2_idx_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_in2_idx(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let gate = tc.draw(gen_gate_node(context.net.nodes.len(), None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Gate(gate.clone());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_allow_connection()
                .times(1)
                .return_const(true);
            context
                .actions
                ._do_set_in2_idx(&mock_deps, &context.state, &mut context.net)
                .unwrap();
            let expected = GateNode {
                gate: gate.gate,
                in1_idx: gate.in1_idx,
                in2_idx: Some(context.state.selected_idx),
                value: gate.value
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Gate(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_in2_idx_blocked(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let gate = tc.draw(gen_gate_node(context.net.nodes.len(), None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Gate(gate.clone());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_allow_connection()
                .times(1)
                .return_const(false);
            context
                .actions
                ._do_set_in2_idx(&mock_deps, &context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Gate(gate)
            );
        }

        #[hegel::test]
        fn test_do_set_in2_idx_input(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let input = tc.draw(gen_input_node(None, None, None));
            context.net.nodes[context.state.node_idx] = LogicNode::Input(input.clone());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_allow_connection()
                .times(1)
                .return_const(true);
            context
                .actions
                ._do_set_in2_idx(&mock_deps, &context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                LogicNode::Input(input)
            );
        }

        #[hegel::test]
        fn test_do_set_in2_idx_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = tc.draw(gen_logic_net(Some(true), None));
            let mock_deps = MockLogicActionsDeps::new();
            let result = context
                .actions
                ._do_set_in2_idx(&mock_deps, &context.state, &mut net);
            assert!(result.is_err());
        }

        #[hegel::test]
        fn test_do_set_in2_idx_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let mock_deps = MockLogicActionsDeps::new();
            let result =
                context
                    .actions
                    ._do_set_in2_idx(&mock_deps, &context.state, &mut context.net);
            assert!(result.is_err());
        }
    }

    mod do_meta_action_tests {
        use super::*;

        #[hegel::test]
        fn test_do_meta_action(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let label = tc.draw(gen_text());
            let feat_idx = context.state.feat_idx;
            let n_feats = context.actions.feat_order.len();
            context
                .actions
                .meta_actions
                .insert(label.clone(), vec![Action::NextFeat, Action::NextFeat]);
            LogicActionsDepsImpl.do_meta_action(
                &context.actions,
                &mut context.net,
                &mut context.state,
                label
            );
            assert_eq!(context.state.feat_idx, (feat_idx + 2) % n_feats);
        }

        #[hegel::test]
        fn test_do_meta_action_unknown_label(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let label = tc.draw(gen_text());
            tc.assume(!context.actions.meta_actions.contains_key(&label));
            let feat_idx = context.state.feat_idx;
            LogicActionsDepsImpl.do_meta_action(
                &context.actions,
                &mut context.net,
                &mut context.state,
                label
            );
            assert_eq!(context.state.feat_idx, feat_idx);
        }
    }

    mod do_action_tests {
        use super::*;

        #[hegel::test]
        fn test_do_action_meta_action(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps.expect_do_meta_action().times(1).return_const(());
            let action = Action::MetaAction(tc.draw(gen_text()));
            context
                .actions
                ._do_action(&mock_deps, &mut context.net, &mut context.state, action);
        }

        #[hegel::test]
        fn test_do_action_next_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps.expect_do_next_feat().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::NextFeat
            );
        }

        #[hegel::test]
        fn test_do_action_next_threshold(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_do_next_threshold()
                .times(1)
                .return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::NextThreshold
            );
        }

        #[hegel::test]
        fn test_do_action_next_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps.expect_do_next_node().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::NextNode
            );
        }

        #[hegel::test]
        fn test_do_action_select_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps.expect_do_select_node().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SelectNode
            );
        }

        #[hegel::test]
        fn test_do_action_next_gate(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps.expect_do_next_gate().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::NextGate
            );
        }

        #[hegel::test]
        fn test_do_action_set_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_do_set_feat()
                .times(1)
                .returning(|_, _, _| Ok(()));
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SetFeat
            );
        }

        #[hegel::test]
        fn test_do_action_set_threshold(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_do_set_threshold()
                .times(1)
                .returning(|_, _, _| Ok(()));
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SetThreshold
            );
        }

        #[hegel::test]
        fn test_do_action_set_gate(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_do_set_gate()
                .times(1)
                .returning(|_, _, _| Ok(()));
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SetGate
            );
        }

        #[hegel::test]
        fn test_do_action_set_in1_idx(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_do_set_in1_idx()
                .times(1)
                .returning(|_, _, _| Ok(()));
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SetIn1Idx
            );
        }

        #[hegel::test]
        fn test_do_action_set_in2_idx(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps
                .expect_do_set_in2_idx()
                .times(1)
                .returning(|_, _, _| Ok(()));
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SetIn2Idx
            );
        }

        #[hegel::test]
        fn test_do_action_new_input(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps.expect_do_new_input().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::NewInput
            );
        }

        #[hegel::test]
        fn test_do_action_new_gate(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockLogicActionsDeps::new();
            mock_deps.expect_do_new_gate().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::NewGate
            );
        }
    }

    mod do_action_ignored_tests {
        use super::*;
        #[hegel::test]
        fn test_do_action_ignores_decision_actions(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, None));
            let mut net = tc.draw(gen_logic_net(Some(false), None));
            let mut state = tc.draw(gen_state_for(&actions, Some(net.nodes.len())));
            let net_before = net.clone();
            let feat_idx = state.feat_idx;

            // A bare mock panics on any unexpected call, so this asserts the `_ => {}` arm dispatches nothing.
            let mock_deps = MockLogicActionsDeps::new();
            let action_seq = vec![
                Action::SetTrueIdx,
                Action::SetFalseIdx,
                Action::SetRefIdx,
                Action::NewBranch,
                Action::NewRef
            ];

            for action in action_seq {
                actions._do_action(&mock_deps, &mut net, &mut state, action);
            }

            assert_eq!(net, net_before);
            assert_eq!(state.feat_idx, feat_idx);
        }
    }

    mod actions_list_tests {
        use super::*;
        #[hegel::test]
        fn test_actions_list(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, None));

            let list = actions.actions_list();

            let builtins = vec![
                Action::NextFeat,
                Action::NextThreshold,
                Action::NextNode,
                Action::SelectNode,
                Action::NextGate,
                Action::SetFeat,
                Action::SetThreshold,
                Action::SetGate,
                Action::SetIn1Idx,
                Action::SetIn2Idx,
                Action::NewInput,
                Action::NewGate
            ];
            let n_builtins = builtins.len();
            assert_eq!(list[0..n_builtins], builtins);
            assert_eq!(list.len(), n_builtins + actions.meta_actions.len());

            for label in actions.meta_actions.keys() {
                let meta_action = Action::MetaAction(label.clone());
                assert!(list.contains(&meta_action));
            }
        }
    }

    mod to_json_tests {
        use super::*;
        #[hegel::test]
        fn test_to_json(tc: TestCase) {
            let actions = tc.draw(gen_logic_actions(None, None));

            let value = actions.to_json();

            assert_eq!(value["type"], "logic");
            assert_eq!(
                value["meta_actions"],
                meta_actions_json(&actions.meta_actions)
            );
            assert_eq!(
                value["thresholds"],
                thresholds_json(&actions.thresholds, &actions.feat_order)
            );
            assert_eq!(value["feat_order"], json!(actions.feat_order));
            assert_eq!(value["n_thresholds"], json!(actions.n_thresholds));
            assert_eq!(value["allow_recurrence"], json!(actions.allow_recurrence));
            assert_eq!(value["allowed_gates"], json!(actions.allowed_gates));
        }
    }
}
