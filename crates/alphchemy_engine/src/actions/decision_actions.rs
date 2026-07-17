use std::collections::HashMap;
use serde_json::{json, Value};
#[cfg(test)]
use mockall::automock;

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

#[cfg_attr(test, automock)]
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

#[cfg(test)]
mod tests {
    use super::*;
    use approx::assert_relative_eq;
    use hegel::TestCase;
    use hegel::generators::booleans;
    use crate::actions::actions::tests::{gen_actions_state, gen_meta_actions, gen_thresholds};
    use crate::network::decision_net::tests::gen_decision_net;
    use crate::test_utils::{gen_text, gen_usize_with_max, gen_vec};

    fn sub_actions() -> Vec<Action> {
        vec![Action::NextFeat, Action::NextThreshold, Action::SelectNode]
    }

    fn new_branch_node() -> BranchNode {
        BranchNode { threshold: None, feat_id: None, true_idx: None, false_idx: None, value: false }
    }

    fn new_ref_node() -> RefNode {
        RefNode { ref_idx: None, true_idx: None, false_idx: None, value: false }
    }

    fn empty_net() -> DecisionNet {
        DecisionNet { nodes: Vec::new(), max_trail_len: 1, default_value: false, idx_trail: Vec::new() }
    }

    #[hegel::composite]
    fn gen_decision_actions(tc: TestCase, feat_ids: Option<&[String]>, allow_refs: Option<bool>) -> DecisionActions {
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
        let refs_allowed = allow_refs.unwrap_or_else(|| tc.draw(booleans()));

        DecisionActions {
            meta_actions,
            thresholds,
            feat_order,
            n_thresholds,
            allow_refs: refs_allowed
        }
    }

    #[hegel::composite]
    fn gen_state_for(tc: TestCase, actions: &DecisionActions, n_nodes: usize) -> ActionsState {
        let n_feats = actions.feat_order.len();
        tc.draw(gen_actions_state(n_nodes, n_feats, actions.n_thresholds, 1))
    }

    #[hegel::test]
    fn test_do_next_feat(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let mut state = tc.draw(gen_state_for(&actions, 1));
        let feat_idx = state.feat_idx;

        DecisionActionsDepsImpl.do_next_feat(&actions, &mut state);

        let advanced_idx = feat_idx + 1;
        let expected_idx = advanced_idx % actions.feat_order.len();
        assert_eq!(state.feat_idx, expected_idx);
    }

    #[hegel::test]
    fn test_do_next_threshold(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let mut state = tc.draw(gen_state_for(&actions, 1));
        let threshold_idx = state.threshold_idx;

        DecisionActionsDepsImpl.do_next_threshold(&actions, &mut state);

        let advanced_idx = threshold_idx + 1;
        let expected_idx = advanced_idx % actions.n_thresholds;
        assert_eq!(state.threshold_idx, expected_idx);
    }

    #[hegel::test]
    fn test_do_next_node(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let net = tc.draw(gen_decision_net(Some(false), None, None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let node_idx = state.node_idx;

        DecisionActionsDepsImpl.do_next_node(&mut state, &net);

        let advanced_idx = node_idx + 1;
        let expected_idx = advanced_idx % net.nodes.len();
        assert_eq!(state.node_idx, expected_idx);
    }

    #[hegel::test]
    fn test_do_select_node(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let mut state = tc.draw(gen_state_for(&actions, 5));
        let node_idx = state.node_idx;

        DecisionActionsDepsImpl.do_select_node(&mut state);

        assert_eq!(state.selected_idx, node_idx);
    }

    #[hegel::test]
    fn test_do_set_feat(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let feat_ids = actions.feat_order.clone();
        let mut net = tc.draw(gen_decision_net(Some(false), Some(&feat_ids), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        net.nodes[state.node_idx] = DecisionNode::Branch(new_branch_node());

        DecisionActionsDepsImpl.do_set_feat(&actions, &state, &mut net).unwrap();

        let feat_id = feat_ids[state.feat_idx].clone();
        let expected_branch = BranchNode { threshold: None, feat_id: Some(feat_id), true_idx: None, false_idx: None, value: false };
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Branch(expected_branch));

        let ref_node = new_ref_node();
        net.nodes[state.node_idx] = DecisionNode::Ref(ref_node.clone());
        DecisionActionsDepsImpl.do_set_feat(&actions, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Ref(ref_node));

        let mut net_without_nodes = empty_net();
        let empty_result = DecisionActionsDepsImpl.do_set_feat(&actions, &state, &mut net_without_nodes);
        assert!(empty_result.is_ok());

        state.feat_idx = feat_ids.len();
        let bad_feat_result = DecisionActionsDepsImpl.do_set_feat(&actions, &state, &mut net);
        assert!(bad_feat_result.is_err());

        state.feat_idx = 0;
        state.node_idx = net.nodes.len();
        let bad_node_result = DecisionActionsDepsImpl.do_set_feat(&actions, &state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_set_threshold(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let feat_ids = actions.feat_order.clone();
        let unknown_feat_id = tc.draw(gen_text());
        tc.assume(!feat_ids.contains(&unknown_feat_id));

        let mut net = tc.draw(gen_decision_net(Some(false), Some(&feat_ids), None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let feat_id = feat_ids[state.feat_idx].clone();
        let branch_node = BranchNode { threshold: None, feat_id: Some(feat_id.clone()), true_idx: None, false_idx: None, value: false };
        net.nodes[state.node_idx] = DecisionNode::Branch(branch_node);

        DecisionActionsDepsImpl.do_set_threshold(&actions, &state, &mut net).unwrap();

        let range = &actions.thresholds[&feat_id];
        let expected_threshold = range.value_at(state.threshold_idx, actions.n_thresholds);
        let DecisionNode::Branch(set_node) = &net.nodes[state.node_idx] else { panic!("expected a branch node") };
        assert_relative_eq!(set_node.threshold.unwrap(), expected_threshold, epsilon = 1e-5);

        let featless_node = new_branch_node();
        net.nodes[state.node_idx] = DecisionNode::Branch(featless_node.clone());
        DecisionActionsDepsImpl.do_set_threshold(&actions, &state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Branch(featless_node));

        let unknown_node = BranchNode { threshold: None, feat_id: Some(unknown_feat_id), true_idx: None, false_idx: None, value: false };
        net.nodes[state.node_idx] = DecisionNode::Branch(unknown_node);
        let unknown_result = DecisionActionsDepsImpl.do_set_threshold(&actions, &state, &mut net);
        assert!(unknown_result.is_err());

        let mut net_without_nodes = empty_net();
        let empty_result = DecisionActionsDepsImpl.do_set_threshold(&actions, &state, &mut net_without_nodes);
        assert!(empty_result.is_ok());

        state.node_idx = net.nodes.len();
        let bad_node_result = DecisionActionsDepsImpl.do_set_threshold(&actions, &state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_set_true_idx(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let mut net = tc.draw(gen_decision_net(Some(false), None, None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let selected_idx = state.selected_idx;
        net.nodes[state.node_idx] = DecisionNode::Branch(new_branch_node());

        DecisionActionsDepsImpl.do_set_true_idx(&state, &mut net).unwrap();

        let expected_branch = BranchNode { threshold: None, feat_id: None, true_idx: Some(selected_idx), false_idx: None, value: false };
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Branch(expected_branch));

        net.nodes[state.node_idx] = DecisionNode::Ref(new_ref_node());
        DecisionActionsDepsImpl.do_set_true_idx(&state, &mut net).unwrap();

        let expected_ref = RefNode { ref_idx: None, true_idx: Some(selected_idx), false_idx: None, value: false };
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Ref(expected_ref));

        let mut net_without_nodes = empty_net();
        let empty_result = DecisionActionsDepsImpl.do_set_true_idx(&state, &mut net_without_nodes);
        assert!(empty_result.is_ok());

        state.node_idx = net.nodes.len();
        let bad_node_result = DecisionActionsDepsImpl.do_set_true_idx(&state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_set_false_idx(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let mut net = tc.draw(gen_decision_net(Some(false), None, None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let selected_idx = state.selected_idx;
        net.nodes[state.node_idx] = DecisionNode::Branch(new_branch_node());

        DecisionActionsDepsImpl.do_set_false_idx(&state, &mut net).unwrap();

        let expected_branch = BranchNode { threshold: None, feat_id: None, true_idx: None, false_idx: Some(selected_idx), value: false };
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Branch(expected_branch));

        net.nodes[state.node_idx] = DecisionNode::Ref(new_ref_node());
        DecisionActionsDepsImpl.do_set_false_idx(&state, &mut net).unwrap();

        let expected_ref = RefNode { ref_idx: None, true_idx: None, false_idx: Some(selected_idx), value: false };
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Ref(expected_ref));

        let mut net_without_nodes = empty_net();
        let empty_result = DecisionActionsDepsImpl.do_set_false_idx(&state, &mut net_without_nodes);
        assert!(empty_result.is_ok());

        state.node_idx = net.nodes.len();
        let bad_node_result = DecisionActionsDepsImpl.do_set_false_idx(&state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_set_ref_idx(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let mut net = tc.draw(gen_decision_net(Some(false), None, None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        net.nodes[state.node_idx] = DecisionNode::Ref(new_ref_node());

        DecisionActionsDepsImpl.do_set_ref_idx(&state, &mut net).unwrap();

        let expected_ref = RefNode { ref_idx: Some(state.selected_idx), true_idx: None, false_idx: None, value: false };
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Ref(expected_ref));

        let branch_node = new_branch_node();
        net.nodes[state.node_idx] = DecisionNode::Branch(branch_node.clone());
        DecisionActionsDepsImpl.do_set_ref_idx(&state, &mut net).unwrap();
        assert_eq!(net.nodes[state.node_idx], DecisionNode::Branch(branch_node));

        let mut net_without_nodes = empty_net();
        let empty_result = DecisionActionsDepsImpl.do_set_ref_idx(&state, &mut net_without_nodes);
        assert!(empty_result.is_ok());

        state.node_idx = net.nodes.len();
        let bad_node_result = DecisionActionsDepsImpl.do_set_ref_idx(&state, &mut net);
        assert!(bad_node_result.is_err());
    }

    #[hegel::test]
    fn test_do_new_branch(tc: TestCase) {
        let mut net = tc.draw(gen_decision_net(None, None, None));
        let n_nodes = net.nodes.len();

        DecisionActionsDepsImpl.do_new_branch(&mut net);

        assert_eq!(net.nodes.len(), n_nodes + 1);
        assert_eq!(net.nodes[n_nodes], DecisionNode::Branch(new_branch_node()));
    }

    #[hegel::test]
    fn test_do_new_ref(tc: TestCase) {
        let allowing_actions = tc.draw(gen_decision_actions(None, Some(true)));
        let blocking_actions = tc.draw(gen_decision_actions(None, Some(false)));
        let mut net = tc.draw(gen_decision_net(None, None, None));
        let n_nodes = net.nodes.len();

        DecisionActionsDepsImpl.do_new_ref(&allowing_actions, &mut net);

        assert_eq!(net.nodes.len(), n_nodes + 1);
        assert_eq!(net.nodes[n_nodes], DecisionNode::Ref(new_ref_node()));

        let nodes_before = net.nodes.clone();
        DecisionActionsDepsImpl.do_new_ref(&blocking_actions, &mut net);
        assert_eq!(net.nodes, nodes_before);
    }

    #[hegel::test]
    fn test_do_meta_action(tc: TestCase) {
        let mut actions = tc.draw(gen_decision_actions(None, None));
        let label = tc.draw(gen_text());
        let unknown_label = tc.draw(gen_text());
        tc.assume(label != unknown_label);
        tc.assume(!actions.meta_actions.contains_key(&unknown_label));

        let n_feats = actions.feat_order.len();
        let two_next_feats = vec![Action::NextFeat, Action::NextFeat];
        actions.meta_actions.insert(label.clone(), two_next_feats);

        let mut net = tc.draw(gen_decision_net(Some(false), None, None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let feat_idx = state.feat_idx;

        DecisionActionsDepsImpl.do_meta_action(&actions, &mut net, &mut state, label);

        let advanced_idx = feat_idx + 2;
        let expected_idx = advanced_idx % n_feats;
        assert_eq!(state.feat_idx, expected_idx);

        DecisionActionsDepsImpl.do_meta_action(&actions, &mut net, &mut state, unknown_label);
        assert_eq!(state.feat_idx, expected_idx);
    }

    #[hegel::test]
    fn test_do_action(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let label = tc.draw(gen_text());
        let mut net = tc.draw(gen_decision_net(Some(false), None, None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

        let mut mock_deps = MockDecisionActionsDeps::new();

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

        let new_branch_dep = mock_deps.expect_do_new_branch().times(1);
        new_branch_dep.return_const(());

        let new_ref_dep = mock_deps.expect_do_new_ref().times(1);
        new_ref_dep.return_const(());

        let set_feat_dep = mock_deps.expect_do_set_feat().times(1);
        set_feat_dep.returning(|_, _, _| Ok(()));

        let set_threshold_dep = mock_deps.expect_do_set_threshold().times(1);
        set_threshold_dep.returning(|_, _, _| Ok(()));

        let set_true_idx_dep = mock_deps.expect_do_set_true_idx().times(1);
        set_true_idx_dep.returning(|_, _| Ok(()));

        let set_false_idx_dep = mock_deps.expect_do_set_false_idx().times(1);
        set_false_idx_dep.returning(|_, _| Ok(()));

        let set_ref_idx_dep = mock_deps.expect_do_set_ref_idx().times(1);
        set_ref_idx_dep.returning(|_, _| Ok(()));

        let meta_action = Action::MetaAction(label);
        let action_seq = vec![meta_action, Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::SetFeat, Action::SetThreshold, Action::SetTrueIdx, Action::SetFalseIdx, Action::SetRefIdx, Action::NewBranch, Action::NewRef];

        for action in action_seq {
            actions._do_action(&mock_deps, &mut net, &mut state, action);
        }
    }

    #[hegel::test]
    fn test_do_action_ignores_logic_actions(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));
        let mut net = tc.draw(gen_decision_net(Some(false), None, None));
        let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
        let nodes_before = net.nodes.clone();
        let feat_idx = state.feat_idx;

        // A bare mock panics on any unexpected call, so this asserts the `_ => {}` arm dispatches nothing.
        let mock_deps = MockDecisionActionsDeps::new();
        let action_seq = vec![Action::NextGate, Action::SetGate, Action::SetIn1Idx, Action::SetIn2Idx, Action::NewInput, Action::NewGate];

        for action in action_seq {
            actions._do_action(&mock_deps, &mut net, &mut state, action);
        }

        assert_eq!(net.nodes, nodes_before);
        assert_eq!(state.feat_idx, feat_idx);
    }

    #[hegel::test]
    fn test_actions_list(tc: TestCase) {
        let actions = tc.draw(gen_decision_actions(None, None));

        let list = actions.actions_list();

        let builtins = vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode, Action::SetFeat, Action::SetThreshold, Action::SetTrueIdx, Action::SetFalseIdx, Action::SetRefIdx, Action::NewBranch, Action::NewRef];
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
        let actions = tc.draw(gen_decision_actions(None, None));

        let value = actions.to_json();

        assert_eq!(value["type"], "decision");
        assert_eq!(value["meta_actions"], meta_actions_json(&actions.meta_actions));
        assert_eq!(value["thresholds"], thresholds_json(&actions.thresholds, &actions.feat_order));
        assert_eq!(value["feat_order"], json!(actions.feat_order));
        assert_eq!(value["n_thresholds"], json!(actions.n_thresholds));
        assert_eq!(value["allow_refs"], json!(actions.allow_refs));
        assert_eq!(value["allowed_gates"], Value::Null);
    }
}
