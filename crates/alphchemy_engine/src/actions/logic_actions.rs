use std::collections::HashMap;
use serde_json::{json, Value};

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