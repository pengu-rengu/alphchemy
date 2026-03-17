use std::collections::HashMap;

use crate::actions::actions::{Action, Actions, ActionsState, ThresholdRange};
use crate::network::decision_net::{DecisionNet, DecisionNode, BranchNode, RefNode};

#[derive(Clone, Debug)]
pub struct DecisionActions {
    pub meta_actions: HashMap<Action, Vec<Action>>,
    pub thresholds: Vec<ThresholdRange>,
    pub n_thresholds: usize,
    pub allow_refs: bool
}

impl Actions<DecisionNet> for DecisionActions {
    fn actions_list(&self) -> Vec<Action> {
        vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::NextGate, Action::SetFeatIdx, Action::SetThreshold, Action::SetTrueIdx, Action::SetFalseIdx, Action::SetRefIdx, Action::NewBranch, Action::NewRef]
    }

    fn do_action(&self, net: &mut DecisionNet, state: &mut ActionsState, action: Action) {
        if let Some(sub_actions) = self.meta_actions.get(&action) {
            for sub_action in sub_actions {
                self.do_action(net, state, *sub_action);
            }

            return
        }

        let node_idx = state.node_idx;
        let selected_idx = state.selected_idx;

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
            Action::SetFeatIdx => {
                if let Some(node) = net.nodes.get_mut(node_idx)
                && let DecisionNode::Branch(branch_node) = node {

                    branch_node.feat_idx = Some(state.feat_idx);
                }
            }
            Action::SetThreshold => {
                if let Some(range) = self.thresholds.get(state.feat_idx)
                && let Some(node) = net.nodes.get_mut(node_idx)
                && let DecisionNode::Branch(branch_node) = node {
                    branch_node.threshold = Some(range.value_at(state.threshold_idx, self.n_thresholds));
                }
            }
            Action::SetTrueIdx => {
                if let Some(node) = net.nodes.get_mut(node_idx) {
                    node.set_true_idx(node_idx);
                }
            }
            Action::SetFalseIdx => {
                if let Some(node) = net.nodes.get_mut(node_idx) {
                    node.set_false_idx(node_idx);
                }
            }
            Action::SetRefIdx => {
                if let Some(node) = net.nodes.get_mut(node_idx)
                && let DecisionNode::Ref(ref_node) = node {

                    ref_node.ref_idx = Some(selected_idx);
                }
            }
            Action::NewBranch => {
                net.nodes.push(DecisionNode::Branch(BranchNode {
                    threshold: None,
                    feat_idx: None,
                    true_idx: None,
                    false_idx: None,
                    value: false
                }));
            }
            Action::NewRef => {
                net.nodes.push(DecisionNode::Ref(RefNode {
                    ref_idx: None,
                    true_idx: None,
                    false_idx: None,
                    value: false
                }));
            }
            _ => ()
        }
    }
}