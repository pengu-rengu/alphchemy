use std::collections::HashMap;
use serde_json::{json, Value};

use crate::actions::actions::{Action, Actions, ActionsState, ThresholdRange, meta_actions_json, thresholds_json};
use crate::network::decision_net::{DecisionNet, DecisionNode, BranchNode, RefNode};

#[derive(Clone, Debug)]
pub struct DecisionActions {
    pub meta_actions: HashMap<String, Vec<Action>>,
    pub thresholds: HashMap<String, ThresholdRange>,
    pub feat_order: Vec<String>,
    pub n_thresholds: usize,
    pub allow_refs: bool
}

impl DecisionActions {
    pub fn to_json(&self) -> Value {
        json!({
            "type": "decision",
            "meta_actions": meta_actions_json(&self.meta_actions),
            "thresholds": thresholds_json(&self.thresholds, &self.feat_order),
            "feat_order": self.feat_order,
            "n_thresholds": self.n_thresholds,
            "allow_refs": self.allow_refs
        })
    }
}

impl Actions<DecisionNet> for DecisionActions {
    fn actions_list(&self) -> Vec<Action> {
        let mut list = vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::SetFeat, Action::SetThreshold, Action::SetTrueIdx, Action::SetFalseIdx, Action::SetRefIdx, Action::NewBranch, Action::NewRef];

        for label in self.meta_actions.keys() {
            list.push(Action::MetaAction(label.clone()));
        }

        list
    }

    fn do_action(&self, net: &mut DecisionNet, state: &mut ActionsState, action: Action) {
        let node_idx = state.node_idx;
        let selected_idx = state.selected_idx;

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
            Action::SetFeat => {
                let maybe_feat_id = self.feat_order.get(state.feat_idx);

                if let Some(feat_id) = maybe_feat_id
                && let Some(node) = net.nodes.get_mut(node_idx)
                && let DecisionNode::Branch(branch_node) = node {

                    branch_node.feat_id = Some(feat_id.clone());
                }
            }
            Action::SetThreshold => {
                let maybe_node = net.nodes.get_mut(node_idx);

                if let Some(DecisionNode::Branch(branch_node)) = maybe_node
                && let Some(feat_id) = branch_node.feat_id.clone()
                && let Some(range) = self.thresholds.get(&feat_id) {

                    let threshold = range.value_at(state.threshold_idx, self.n_thresholds);
                    branch_node.threshold = Some(threshold);
                }
            }
            Action::SetTrueIdx => {
                if let Some(node) = net.nodes.get_mut(node_idx) {
                    node.set_true_idx(selected_idx);
                }
            }
            Action::SetFalseIdx => {
                if let Some(node) = net.nodes.get_mut(node_idx) {
                    node.set_false_idx(selected_idx);
                }
            }
            Action::SetRefIdx => {
                if let Some(node) = net.nodes.get_mut(node_idx)
                && let DecisionNode::Ref(ref_node) = node {

                    ref_node.ref_idx = Some(selected_idx);
                }
            }
            Action::NewBranch => {
                let branch_node = BranchNode {
                    threshold: None,
                    feat_id: None,
                    true_idx: None,
                    false_idx: None,
                    value: false
                };
                let new_node = DecisionNode::Branch(branch_node);
                net.nodes.push(new_node);
            }
            Action::NewRef => {
                if self.allow_refs {
                    let ref_node = RefNode {
                        ref_idx: None,
                        true_idx: None,
                        false_idx: None,
                        value: false
                    };
                    let new_node = DecisionNode::Ref(ref_node);
                    net.nodes.push(new_node);
                }
            }
            _ => ()
        }
    }
}
