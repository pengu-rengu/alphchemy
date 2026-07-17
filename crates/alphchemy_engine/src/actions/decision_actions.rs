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
    use crate::actions::actions::tests::{gen_actions_state, gen_meta_actions, gen_thresholds};
    use crate::network::decision_net::tests::gen_decision_net;
    use crate::test_utils::{gen_text, gen_usize_with_max, gen_vec};
    use approx::assert_relative_eq;
    use hegel::generators::booleans;
    use hegel::TestCase;

    fn sub_actions() -> Vec<Action> {
        vec![Action::NextFeat, Action::NextThreshold, Action::SelectNode]
    }

    fn new_branch_node() -> BranchNode {
        BranchNode {
            threshold: None,
            feat_id: None,
            true_idx: None,
            false_idx: None,
            value: false
        }
    }

    fn new_ref_node() -> RefNode {
        RefNode {
            ref_idx: None,
            true_idx: None,
            false_idx: None,
            value: false
        }
    }

    fn empty_net() -> DecisionNet {
        DecisionNet {
            nodes: Vec::new(),
            max_trail_len: 1,
            default_value: false,
            idx_trail: Vec::new()
        }
    }

    #[hegel::composite]
    fn gen_decision_actions(
        tc: TestCase,
        feat_ids: Option<&[String]>,
        allow_refs: Option<bool>
    ) -> DecisionActions {
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

    #[derive(Debug)]
    struct TestContext {
        actions: DecisionActions,
        net: DecisionNet,
        state: ActionsState
    }

    #[hegel::composite]
    fn gen_context(tc: TestCase) -> TestContext {
        let actions = tc.draw(gen_decision_actions(None, None));
        let feat_ids = actions.feat_order.clone();
        let net = tc.draw(gen_decision_net(Some(false), Some(&feat_ids), None));
        let state = tc.draw(gen_state_for(&actions, net.nodes.len()));

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
            let actions = tc.draw(gen_decision_actions(None, None));
            let mut state = tc.draw(gen_state_for(&actions, 1));
            let feat_idx = state.feat_idx;

            DecisionActionsDepsImpl.do_next_feat(&actions, &mut state);

            let advanced_idx = feat_idx + 1;
            let expected_idx = advanced_idx % actions.feat_order.len();
            assert_eq!(state.feat_idx, expected_idx);
        }
    }

    mod do_next_threshold_tests {
        use super::*;

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
    }

    mod do_next_node_tests {
        use super::*;

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
    }

    mod do_select_node_tests {
        use super::*;

        #[hegel::test]
        fn test_do_select_node(tc: TestCase) {
            let actions = tc.draw(gen_decision_actions(None, None));
            let mut state = tc.draw(gen_state_for(&actions, 5));
            let node_idx = state.node_idx;

            DecisionActionsDepsImpl.do_select_node(&mut state);

            assert_eq!(state.selected_idx, node_idx);
        }
    }

    mod do_set_feat_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.net.nodes[context.state.node_idx] = DecisionNode::Branch(new_branch_node());
            let feat_id = context.actions.feat_order[context.state.feat_idx].clone();

            DecisionActionsDepsImpl
                .do_set_feat(&context.actions, &context.state, &mut context.net)
                .unwrap();

            let expected = BranchNode {
                threshold: None,
                feat_id: Some(feat_id),
                true_idx: None,
                false_idx: None,
                value: false
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Branch(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_feat_ref(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let ref_node = new_ref_node();
            context.net.nodes[context.state.node_idx] = DecisionNode::Ref(ref_node.clone());

            DecisionActionsDepsImpl
                .do_set_feat(&context.actions, &context.state, &mut context.net)
                .unwrap();

            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Ref(ref_node)
            );
        }

        #[hegel::test]
        fn test_do_set_feat_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = empty_net();
            let result =
                DecisionActionsDepsImpl.do_set_feat(&context.actions, &context.state, &mut net);
            assert!(result.is_ok());
        }

        #[hegel::test]
        fn test_do_set_feat_missing_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.feat_idx = context.actions.feat_order.len();
            let result = DecisionActionsDepsImpl.do_set_feat(
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
            let result = DecisionActionsDepsImpl.do_set_feat(
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
            let branch = BranchNode {
                threshold: None,
                feat_id: Some(feat_id.clone()),
                true_idx: None,
                false_idx: None,
                value: false
            };
            context.net.nodes[context.state.node_idx] = DecisionNode::Branch(branch);

            DecisionActionsDepsImpl
                .do_set_threshold(&context.actions, &context.state, &mut context.net)
                .unwrap();

            let range = &context.actions.thresholds[&feat_id];
            let expected =
                range.value_at(context.state.threshold_idx, context.actions.n_thresholds);
            let DecisionNode::Branch(node) = &context.net.nodes[context.state.node_idx] else {
                panic!("expected a branch node")
            };
            assert_relative_eq!(node.threshold.unwrap(), expected, epsilon = 1e-5);
        }

        #[hegel::test]
        fn test_do_set_threshold_no_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let branch = new_branch_node();
            context.net.nodes[context.state.node_idx] = DecisionNode::Branch(branch.clone());
            DecisionActionsDepsImpl
                .do_set_threshold(&context.actions, &context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Branch(branch)
            );
        }

        #[hegel::test]
        fn test_do_set_threshold_unknown_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let feat_id = tc.draw(gen_text());
            tc.assume(!context.actions.feat_order.contains(&feat_id));
            let branch = BranchNode {
                threshold: None,
                feat_id: Some(feat_id),
                true_idx: None,
                false_idx: None,
                value: false
            };
            context.net.nodes[context.state.node_idx] = DecisionNode::Branch(branch);
            let result = DecisionActionsDepsImpl.do_set_threshold(
                &context.actions,
                &context.state,
                &mut context.net
            );
            assert!(result.is_err());
        }

        #[hegel::test]
        fn test_do_set_threshold_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = empty_net();
            let result = DecisionActionsDepsImpl.do_set_threshold(
                &context.actions,
                &context.state,
                &mut net
            );
            assert!(result.is_ok());
        }

        #[hegel::test]
        fn test_do_set_threshold_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let result = DecisionActionsDepsImpl.do_set_threshold(
                &context.actions,
                &context.state,
                &mut context.net
            );
            assert!(result.is_err());
        }
    }

    mod do_set_true_idx_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_true_idx_branch(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.net.nodes[context.state.node_idx] = DecisionNode::Branch(new_branch_node());
            DecisionActionsDepsImpl
                .do_set_true_idx(&context.state, &mut context.net)
                .unwrap();
            let expected = BranchNode {
                threshold: None,
                feat_id: None,
                true_idx: Some(context.state.selected_idx),
                false_idx: None,
                value: false
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Branch(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_true_idx_ref(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.net.nodes[context.state.node_idx] = DecisionNode::Ref(new_ref_node());
            DecisionActionsDepsImpl
                .do_set_true_idx(&context.state, &mut context.net)
                .unwrap();
            let expected = RefNode {
                ref_idx: None,
                true_idx: Some(context.state.selected_idx),
                false_idx: None,
                value: false
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Ref(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_true_idx_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = empty_net();
            let result = DecisionActionsDepsImpl.do_set_true_idx(&context.state, &mut net);
            assert!(result.is_ok());
        }

        #[hegel::test]
        fn test_do_set_true_idx_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let result = DecisionActionsDepsImpl.do_set_true_idx(&context.state, &mut context.net);
            assert!(result.is_err());
        }
    }

    mod do_set_false_idx_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_false_idx_branch(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.net.nodes[context.state.node_idx] = DecisionNode::Branch(new_branch_node());
            DecisionActionsDepsImpl
                .do_set_false_idx(&context.state, &mut context.net)
                .unwrap();
            let expected = BranchNode {
                threshold: None,
                feat_id: None,
                true_idx: None,
                false_idx: Some(context.state.selected_idx),
                value: false
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Branch(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_false_idx_ref(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.net.nodes[context.state.node_idx] = DecisionNode::Ref(new_ref_node());
            DecisionActionsDepsImpl
                .do_set_false_idx(&context.state, &mut context.net)
                .unwrap();
            let expected = RefNode {
                ref_idx: None,
                true_idx: None,
                false_idx: Some(context.state.selected_idx),
                value: false
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Ref(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_false_idx_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = empty_net();
            let result = DecisionActionsDepsImpl.do_set_false_idx(&context.state, &mut net);
            assert!(result.is_ok());
        }

        #[hegel::test]
        fn test_do_set_false_idx_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let result = DecisionActionsDepsImpl.do_set_false_idx(&context.state, &mut context.net);
            assert!(result.is_err());
        }
    }

    mod do_set_ref_idx_tests {
        use super::*;

        #[hegel::test]
        fn test_do_set_ref_idx(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.net.nodes[context.state.node_idx] = DecisionNode::Ref(new_ref_node());
            DecisionActionsDepsImpl
                .do_set_ref_idx(&context.state, &mut context.net)
                .unwrap();
            let expected = RefNode {
                ref_idx: Some(context.state.selected_idx),
                true_idx: None,
                false_idx: None,
                value: false
            };
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Ref(expected)
            );
        }

        #[hegel::test]
        fn test_do_set_ref_idx_branch(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let branch = new_branch_node();
            context.net.nodes[context.state.node_idx] = DecisionNode::Branch(branch.clone());
            DecisionActionsDepsImpl
                .do_set_ref_idx(&context.state, &mut context.net)
                .unwrap();
            assert_eq!(
                context.net.nodes[context.state.node_idx],
                DecisionNode::Branch(branch)
            );
        }

        #[hegel::test]
        fn test_do_set_ref_idx_empty_net(tc: TestCase) {
            let context = tc.draw(gen_context());
            let mut net = empty_net();
            let result = DecisionActionsDepsImpl.do_set_ref_idx(&context.state, &mut net);
            assert!(result.is_ok());
        }

        #[hegel::test]
        fn test_do_set_ref_idx_missing_node(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            context.state.node_idx = context.net.nodes.len();
            let result = DecisionActionsDepsImpl.do_set_ref_idx(&context.state, &mut context.net);
            assert!(result.is_err());
        }
    }

    mod do_new_branch_tests {
        use super::*;

        #[hegel::test]
        fn test_do_new_branch(tc: TestCase) {
            let mut net = tc.draw(gen_decision_net(None, None, None));
            let n_nodes = net.nodes.len();

            DecisionActionsDepsImpl.do_new_branch(&mut net);

            assert_eq!(net.nodes.len(), n_nodes + 1);
            assert_eq!(net.nodes[n_nodes], DecisionNode::Branch(new_branch_node()));
        }
    }

    mod do_new_ref_tests {
        use super::*;

        #[hegel::test]
        fn test_do_new_ref(tc: TestCase) {
            let actions = tc.draw(gen_decision_actions(None, Some(true)));
            let mut net = tc.draw(gen_decision_net(None, None, None));
            let n_nodes = net.nodes.len();
            DecisionActionsDepsImpl.do_new_ref(&actions, &mut net);
            assert_eq!(net.nodes.len(), n_nodes + 1);
            assert_eq!(net.nodes[n_nodes], DecisionNode::Ref(new_ref_node()));
        }

        #[hegel::test]
        fn test_do_new_ref_blocked(tc: TestCase) {
            let actions = tc.draw(gen_decision_actions(None, Some(false)));
            let mut net = tc.draw(gen_decision_net(None, None, None));
            let nodes = net.nodes.clone();
            DecisionActionsDepsImpl.do_new_ref(&actions, &mut net);
            assert_eq!(net.nodes, nodes);
        }
    }

    mod do_meta_action_tests {
        use super::*;

        #[hegel::test]
        fn test_do_meta_action(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let label = tc.draw(gen_text());
            let n_feats = context.actions.feat_order.len();
            let feat_idx = context.state.feat_idx;
            context
                .actions
                .meta_actions
                .insert(label.clone(), vec![Action::NextFeat, Action::NextFeat]);
            DecisionActionsDepsImpl.do_meta_action(
                &context.actions,
                &mut context.net,
                &mut context.state,
                label
            );
            let expected_idx = (feat_idx + 2) % n_feats;
            assert_eq!(context.state.feat_idx, expected_idx);
        }

        #[hegel::test]
        fn test_do_meta_action_unknown_label(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let label = tc.draw(gen_text());
            tc.assume(!context.actions.meta_actions.contains_key(&label));
            let feat_idx = context.state.feat_idx;
            let node_idx = context.state.node_idx;
            let selected_idx = context.state.selected_idx;
            let threshold_idx = context.state.threshold_idx;
            let extra_idx = context.state.extra_idx;
            DecisionActionsDepsImpl.do_meta_action(
                &context.actions,
                &mut context.net,
                &mut context.state,
                label
            );
            assert_eq!(context.state.feat_idx, feat_idx);
            assert_eq!(context.state.node_idx, node_idx);
            assert_eq!(context.state.selected_idx, selected_idx);
            assert_eq!(context.state.threshold_idx, threshold_idx);
            assert_eq!(context.state.extra_idx, extra_idx);
        }
    }

    mod do_action_tests {
        use super::*;

        #[hegel::test]
        fn test_do_action_meta_action(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockDecisionActionsDeps::new();
            mock_deps.expect_do_meta_action().times(1).return_const(());
            let action = Action::MetaAction(tc.draw(gen_text()));
            context
                .actions
                ._do_action(&mock_deps, &mut context.net, &mut context.state, action);
        }

        #[hegel::test]
        fn test_do_action_next_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockDecisionActionsDeps::new();
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
            let mut mock_deps = MockDecisionActionsDeps::new();
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
            let mut mock_deps = MockDecisionActionsDeps::new();
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
            let mut mock_deps = MockDecisionActionsDeps::new();
            mock_deps.expect_do_select_node().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SelectNode
            );
        }

        #[hegel::test]
        fn test_do_action_set_feat(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockDecisionActionsDeps::new();
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
            let mut mock_deps = MockDecisionActionsDeps::new();
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
        fn test_do_action_set_true_idx(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockDecisionActionsDeps::new();
            mock_deps
                .expect_do_set_true_idx()
                .times(1)
                .returning(|_, _| Ok(()));
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SetTrueIdx
            );
        }

        #[hegel::test]
        fn test_do_action_set_false_idx(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockDecisionActionsDeps::new();
            mock_deps
                .expect_do_set_false_idx()
                .times(1)
                .returning(|_, _| Ok(()));
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SetFalseIdx
            );
        }

        #[hegel::test]
        fn test_do_action_set_ref_idx(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockDecisionActionsDeps::new();
            mock_deps
                .expect_do_set_ref_idx()
                .times(1)
                .returning(|_, _| Ok(()));
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::SetRefIdx
            );
        }

        #[hegel::test]
        fn test_do_action_new_branch(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockDecisionActionsDeps::new();
            mock_deps.expect_do_new_branch().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::NewBranch
            );
        }

        #[hegel::test]
        fn test_do_action_new_ref(tc: TestCase) {
            let mut context = tc.draw(gen_context());
            let mut mock_deps = MockDecisionActionsDeps::new();
            mock_deps.expect_do_new_ref().times(1).return_const(());
            context.actions._do_action(
                &mock_deps,
                &mut context.net,
                &mut context.state,
                Action::NewRef
            );
        }
    }

    mod do_action_ignored_tests {
        use super::*;

        #[hegel::test]
        fn test_do_action_ignores_logic_actions(tc: TestCase) {
            let actions = tc.draw(gen_decision_actions(None, None));
            let mut net = tc.draw(gen_decision_net(Some(false), None, None));
            let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));
            let nodes_before = net.nodes.clone();
            let feat_idx = state.feat_idx;

            // A bare mock panics on any unexpected call, so this asserts the `_ => {}` arm dispatches nothing.
            let mock_deps = MockDecisionActionsDeps::new();
            let action_seq = vec![
                Action::NextGate,
                Action::SetGate,
                Action::SetIn1Idx,
                Action::SetIn2Idx,
                Action::NewInput,
                Action::NewGate
            ];

            for action in action_seq {
                actions._do_action(&mock_deps, &mut net, &mut state, action);
            }

            assert_eq!(net.nodes, nodes_before);
            assert_eq!(state.feat_idx, feat_idx);
        }
    }

    mod actions_list_tests {
        use super::*;

        #[hegel::test]
        fn test_actions_list(tc: TestCase) {
            let actions = tc.draw(gen_decision_actions(None, None));

            let list = actions.actions_list();

            let builtins = vec![
                Action::NextFeat,
                Action::NextThreshold,
                Action::NextNode,
                Action::SelectNode,
                Action::SetFeat,
                Action::SetThreshold,
                Action::SetTrueIdx,
                Action::SetFalseIdx,
                Action::SetRefIdx,
                Action::NewBranch,
                Action::NewRef
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
            let actions = tc.draw(gen_decision_actions(None, None));

            let value = actions.to_json();

            assert_eq!(value["type"], "decision");
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
            assert_eq!(value["allow_refs"], json!(actions.allow_refs));
            assert_eq!(value["allowed_gates"], Value::Null);
        }
    }
}
