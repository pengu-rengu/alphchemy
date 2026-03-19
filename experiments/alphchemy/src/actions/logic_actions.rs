use std::collections::HashMap;

use serde::Deserialize;
use serde_json::Value;
use crate::features::features::Feature;
use crate::actions::actions::{Action, Actions, ActionsState, ThresholdRange, parse_meta_actions, parse_thresholds};
use crate::utils::{parse_json, get_field};
use crate::network::logic_net::{LogicNet, LogicNode, Gate, InputNode, GateNode};

#[derive(Clone, Debug, Deserialize)]
pub struct LogicActions {
    #[serde(skip)]
    pub meta_actions: HashMap<Action, Vec<Action>>,
    #[serde(skip)]
    pub thresholds: Vec<ThresholdRange>,
    pub n_thresholds: usize,
    pub allow_recurrence: bool,
    pub allowed_gates: Vec<Gate>
}

impl Actions<LogicNet> for LogicActions {
    fn actions_list(&self) -> Vec<Action> {
        vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::NextGate, Action::SetFeatIdx, Action::SetThreshold, Action::SetGate, Action::SetIn1Idx, Action::SetIn2Idx, Action::NewInput, Action::NewGate]
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
            Action::NextFeat => state.next_feat(self.thresholds.len()),
            Action::NextThreshold => state.next_threshold(self.n_thresholds),
            Action::NextNode => state.next_node(net.nodes.len()),
            Action::SelectNode => state.select_node(),
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
                if let Some(range) = self.thresholds.get(state.feat_idx)
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

pub fn parse_logic_actions(json: &Value, feats: &[Box<dyn Feature>]) -> Result<LogicActions, String> {
    let mut actions = parse_json::<LogicActions>(json)?;

    let meta_json = get_field(json, "meta_actions")?;
    actions.meta_actions = parse_meta_actions(meta_json)?;

    let thresholds_json = get_field(json, "thresholds")?;
    actions.thresholds = parse_thresholds(thresholds_json, feats)?;

    if actions.n_thresholds == 0 {
        return Err("n_thresholds must be > 0".to_string());
    }

    Ok(actions)
}
