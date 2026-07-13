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

trait DecisionActionsDeps {
    fn do_meta_action(&self, actions: &DecisionActions, net: &mut DecisionNet, state: &mut ActionsState, label: String) {
        if let Some(sub_actions) = actions.meta_actions.get(&label) {
            for sub_action in sub_actions {
                actions.do_action(net, state, sub_action.clone());
            }
        }
    }

    fn do_next_feat(&self, actions: &DecisionActions, state: &mut ActionsState) {
        state.next_feat(actions.feat_order.len());
    }

    fn do_next_threshold(&self, actions: &DecisionActions, state: &mut ActionsState) {
        state.next_threshold(actions.n_thresholds);
    }

    fn do_next_node(&self, state: &mut ActionsState, net: &DecisionNet) {
        state.next_node(net.nodes.len());
    }

    fn do_select_node(&self, state: &mut ActionsState) {
        state.select_node();
    }

    fn do_set_feat(&self, actions: &DecisionActions, state: &ActionsState, net: &mut DecisionNet) -> Result<(), String> {
        if net.nodes.is_empty() { return Ok(()) }

        let feat_idx = state.feat_idx;
        let Some(feat_id) = actions.feat_order.get(feat_idx) else {
            return Err(format!("Couldn't find feature ID at index {feat_idx} in feat_order while doing set_feat action"))
        };

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in decision network while doing set_feat action"))
        };

        if let DecisionNode::Branch(branch_node) = node {
            branch_node.feat_id = Some(feat_id.clone());
        }

        Ok(())
    }

    fn do_set_threshold(&self, actions: &DecisionActions, state: &ActionsState, net: &mut DecisionNet) -> Result<(), String> {
        if net.nodes.is_empty() { return Ok(()) }

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in decision network while doing set_threshold action"))
        };

        if let DecisionNode::Branch(branch_node) = node
        && let Some(feat_id) = branch_node.feat_id.clone() {
            let Some(range) = actions.thresholds.get(&feat_id) else {
                return Err(format!("Couldn't find threshold range for feature ID {feat_id} while doing set_threshold action"))
            };
            branch_node.threshold = Some(range.value_at(state.threshold_idx, actions.n_thresholds));
        }

        Ok(())
    }

    fn do_set_true_idx(&self, state: &ActionsState, net: &mut DecisionNet) -> Result<(), String> {
        if net.nodes.is_empty() { return Ok(()) }

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in decision network while doing set_true_idx action"))
        };

        node.set_true_idx(state.selected_idx);
        Ok(())
    }

    fn do_set_false_idx(&self, state: &ActionsState, net: &mut DecisionNet) -> Result<(), String> {
        if net.nodes.is_empty() { return Ok(()) }

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in decision network while doing set_false_idx action"))
        };

        node.set_false_idx(state.selected_idx);
        Ok(())
    }

    fn do_set_ref_idx(&self, state: &ActionsState, net: &mut DecisionNet) -> Result<(), String> {
        if net.nodes.is_empty() { return Ok(()) }

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in decision network while doing set_ref_idx action"))
        };

        if let DecisionNode::Ref(ref_node) = node {
            ref_node.ref_idx = Some(state.selected_idx);
        }

        Ok(())
    }

    fn do_new_branch(&self, net: &mut DecisionNet) {
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

    fn do_new_ref(&self, actions: &DecisionActions, net: &mut DecisionNet) {
        if actions.allow_refs {
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
}

struct DecisionActionsDepsImpl;
impl DecisionActionsDeps for DecisionActionsDepsImpl {}

impl DecisionActions {
    fn _do_action<T>(&self, deps: &T, net: &mut DecisionNet, state: &mut ActionsState, action: Action) where T: DecisionActionsDeps {
        // TODO: remove unwrap, propagate errors
        match action {
            Action::MetaAction(label) => deps.do_meta_action(self, net, state, label),
            Action::NextFeat => deps.do_next_feat(self, state),
            Action::NextThreshold => deps.do_next_threshold(self, state),
            Action::NextNode => deps.do_next_node(state, net),
            Action::SelectNode => deps.do_select_node(state),
            Action::SetFeat => deps.do_set_feat(self, state, net).unwrap(),
            Action::SetThreshold => deps.do_set_threshold(self, state, net).unwrap(),
            Action::SetTrueIdx => deps.do_set_true_idx(state, net).unwrap(),
            Action::SetFalseIdx => deps.do_set_false_idx(state, net).unwrap(),
            Action::SetRefIdx => deps.do_set_ref_idx(state, net).unwrap(),
            Action::NewBranch => deps.do_new_branch(net),
            Action::NewRef => deps.do_new_ref(self, net),
            _ => {}
        }
    }
}

impl Actions<DecisionNet> for DecisionActions {
    fn to_json(&self) -> Value {
        json!({
            "type": "decision",
            "meta_actions": meta_actions_json(&self.meta_actions),
            "thresholds": thresholds_json(&self.thresholds, &self.feat_order),
            "feat_order": self.feat_order,
            "n_thresholds": self.n_thresholds,
            "allow_refs": self.allow_refs
        })
    }

    fn actions_list(&self) -> Vec<Action> {
        let mut list = vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::SetFeat, Action::SetThreshold, Action::SetTrueIdx, Action::SetFalseIdx, Action::SetRefIdx, Action::NewBranch, Action::NewRef];

        for label in self.meta_actions.keys() {
            list.push(Action::MetaAction(label.clone()));
        }

        list
    }

    fn do_action(&self, net: &mut DecisionNet, state: &mut ActionsState, action: Action) {
        self._do_action(&DecisionActionsDepsImpl, net, state, action);
    }
}
