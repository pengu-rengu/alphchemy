use std::collections::HashMap;

use serde::Deserialize;
use serde_json::Value;
use crate::features::features::Feature;
use crate::actions::actions::{Action, Actions, ActionsState, ThresholdRange, parse_meta_actions, parse_thresholds, validate_feat_order};
use crate::utils::{parse_json, get_field};
use crate::network::logic_net::{LogicNet, LogicNode, Gate, InputNode, GateNode};

#[derive(Clone, Debug, Deserialize)]
pub struct LogicActions {
    #[serde(skip)]
    pub meta_actions: HashMap<String, Vec<Action>>,
    #[serde(skip)]
    pub thresholds: HashMap<String, ThresholdRange>,
    pub feat_order: Vec<String>,
    pub n_thresholds: usize,
    pub allow_recurrence: bool,
    pub allowed_gates: Vec<Gate>
}

impl Actions<LogicNet> for LogicActions {
    fn actions_list(&self) -> Vec<Action> {
        let mut list = vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::NextGate, Action::SetFeat, Action::SetThreshold, Action::SetGate, Action::SetIn1Idx, Action::SetIn2Idx, Action::NewInput, Action::NewGate];

        for label in self.meta_actions.keys() {
            list.push(Action::MetaAction(label.clone()));
        }

        list
    }

    fn do_action(&self, net: &mut LogicNet, state: &mut ActionsState, action: Action) {
        let node_idx = state.node_idx;
        let selected_idx = state.selected_idx;

        let is_feedforward = state.selected_idx < node_idx;
        let allow_connection = self.allow_recurrence || is_feedforward;

        match action {
            Action::MetaAction(label) => {
                if let Some(sub_actions) = self.meta_actions.get(&label) {
                    for sub_action in sub_actions {
                        self.do_action(net, state, sub_action.clone());
                    }
                }
            }
            Action::NextFeat => state.next_feat(self.feat_order.len()),
            Action::NextThreshold => state.next_threshold(self.n_thresholds),
            Action::NextNode => state.next_node(net.nodes.len()),
            Action::SelectNode => state.select_node(),
            Action::NextGate => {
                state.extra_idx += 1;
                if state.extra_idx >= self.allowed_gates.len() {
                    state.extra_idx = 0;
                }
            }
            Action::SetFeat => {
                let maybe_feat_id = self.feat_order.get(state.feat_idx);

                if let Some(feat_id) = maybe_feat_id
                && let Some(node) = net.nodes.get_mut(node_idx)
                && let LogicNode::Input(input_node) = node {

                    input_node.feat_id = Some(feat_id.clone());
                }
            }
            Action::SetThreshold => {
                let maybe_feat_id = self.feat_order.get(state.feat_idx);

                if let Some(feat_id) = maybe_feat_id
                && let Some(range) = self.thresholds.get(feat_id)
                && let Some(node) = net.nodes.get_mut(node_idx)
                && let LogicNode::Input(input_node) = node {
                    
                    let threshold = range.value_at(state.threshold_idx, self.n_thresholds);
                    input_node.threshold = Some(threshold);
                }
            }
            Action::SetGate => {
                if let Some(&gate) = self.allowed_gates.get(state.extra_idx)
                && let Some(node) = net.nodes.get_mut(node_idx)
                && let LogicNode::Gate(gate_node) = node {
                    
                    gate_node.gate = Some(gate);
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
                let input_node = InputNode {
                    threshold: None,
                    feat_id: None,
                    value: false
                };
                let new_node = LogicNode::Input(input_node);
                net.nodes.push(new_node);
            }
            Action::NewGate => {
                let gate_node = GateNode {
                    gate: None,
                    in1_idx: None,
                    in2_idx: None,
                    value: false
                };
                let new_node = LogicNode::Gate(gate_node);
                net.nodes.push(new_node);
            }
            _ => {}
        }
    }
}

pub fn parse_logic_actions(json: &Value, feats: &[Box<dyn Feature>]) -> Result<LogicActions, String> {
    let mut actions = parse_json::<LogicActions>(json)?;

    let meta_json = get_field(json, "meta_actions")?;
    actions.meta_actions = parse_meta_actions(meta_json)?;

    let thresholds_json = get_field(json, "thresholds")?;
    actions.thresholds = parse_thresholds(thresholds_json, feats)?;

    if actions.n_thresholds == 0 {
        return Err("n_thresholds must be > 0".to_string());
    }

    validate_feat_order(&actions.feat_order, feats)?;

    Ok(actions)
}
