use std::collections::HashMap;

use crate::actions::actions::{Action, Actions, ActionsState, ThresholdRange};
use crate::network::logic_net::{LogicNet, LogicNode, Gate, InputNode, GateNode};

#[derive(Clone, Debug)]
pub struct LogicActions {
    pub meta_actions: HashMap<Action, Vec<Action>>,
    pub thresholds: Vec<ThresholdRange>,
    pub n_thresholds: usize,
    pub allow_recurrence: bool,
    pub allowed_gates: Vec<Gate>
}

impl Actions<LogicNet> for LogicActions {
    fn actions_list(&self) -> Vec<Action> {
        vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::NextGate,  Action::SetFeatIdx, Action::SetThreshold, Action::SetGate, Action::SetIn1Idx, Action::SetIn2Idx, Action::NewInput, Action::NewGate]
    }

    fn do_action(&self, net: &mut LogicNet, state: &mut ActionsState, action: Action) {
        if let Some(sub_actions) = self.meta_actions.get(&action) {
            for sub_action in sub_actions {
                self.do_action(net, state, *sub_action);
            }

            return
        }

        let node_idx = state.node_idx;
        let selected_idx = state.selected_idx;

        let is_feedforward = state.selected_idx < node_idx;
        let allow_connection = self.allow_recurrence || is_feedforward;

        match action {
            Action::NextFeat => {
                state.feat_idx += 1;
                if state.feat_idx >= net.nodes.len() {
                    state.feat_idx = 0;
                }
            }
            Action::NextThreshold => {
                state.threshold_idx += 1;
                if state.threshold_idx >= self.n_thresholds {
                    state.threshold_idx = 0;
                }
            }
            Action::NextNode => {
                state.node_idx += 1;
                if state.node_idx >= net.nodes.len() {
                    state.node_idx = 0;
                }
            }
            Action::SelectNode => {
                state.selected_idx = node_idx;
            }
            Action::NextGate => {
                state.extra_idx += 1;
                if state.extra_idx >= self.allowed_gates.len() {
                    state.extra_idx = 0;
                }
            }
            Action::SetFeatIdx => {
                if let Some(node) = net.nodes.get_mut(node_idx)
                && let LogicNode::Input(input_node) = node {
                    
                    input_node.feat_idx = Some(state.feat_idx);
                }
            }
            Action::SetThreshold => {
                todo!()
            }
            Action::SetGate => {
                if let Some(node) = net.nodes.get_mut(node_idx)
                && let LogicNode::Gate(gate_node) = node {
                    
                    gate_node.gate = Some(self.allowed_gates[state.extra_idx]);
                    
                }
            }
            Action::SetIn1Idx => {
                if allow_connection 
                && let Some(node) = net.nodes.get_mut(node_idx) 
                && let LogicNode::Gate(gate_node) = node {

                    gate_node.in1_idx = Some(selected_idx);
                }
            }
            Action::SetIn2Idx => {
                if allow_connection 
                && let Some(node) = net.nodes.get_mut(node_idx) 
                && let LogicNode::Gate(gate_node) = node {
                    
                    gate_node.in2_idx = Some(selected_idx);   
                }
            }
            Action::NewInput => {
                net.nodes.push(LogicNode::Input(InputNode {
                    threshold: None,
                    feat_idx: None,
                    value: false
                }));
            }
            Action::NewGate => {
                net.nodes.push(LogicNode::Gate(GateNode {
                    gate: None,
                    in1_idx: None,
                    in2_idx: None,
                    value: false
                }));
            }
            _ => {}
        }
    }
}