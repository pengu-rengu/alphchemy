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
    fn value_at(&self, range: &ThresholdRange, idx: usize, n_thresholds: usize) -> f64 {
        range.value_at(idx, n_thresholds)
    }

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
        actions._do_set_threshold(&DecisionActionsDepsImpl, state, net)
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
    fn _do_set_threshold<T>(&self, deps: &T, state: &ActionsState, net: &mut DecisionNet) -> Result<(), String> where T: DecisionActionsDeps {
        if net.nodes.is_empty() { return Ok(()) }

        let node_idx = state.node_idx;
        let Some(node) = net.nodes.get_mut(node_idx) else {
            return Err(format!("Couldn't find node at index {node_idx} in decision network while doing set_threshold action"))
        };

        if let DecisionNode::Branch(branch_node) = node
        && let Some(feat_id) = branch_node.feat_id.clone() {
            let Some(range) = self.thresholds.get(&feat_id) else {
                return Err(format!("Couldn't find threshold range for feature ID {feat_id} while doing set_threshold action"))
            };
            branch_node.threshold = Some(deps.value_at(range, state.threshold_idx, self.n_thresholds));
        }

        Ok(())
    }

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
    use crate::network::decision_net::tests::{gen_branch_node, gen_decision_net, gen_ref_node};
    use crate::test_utils::{gen_f64, gen_text, gen_usize_between, gen_usize_with_max, gen_usize_with_min, gen_vec};
    use hegel::generators::{booleans, sampled_from};
    use hegel::TestCase;

    #[hegel::composite]
    fn gen_sub_actions(tc: TestCase) -> Vec<Action> {
        let seq_len = tc.draw(gen_usize_with_max(4)) + 1;
        let gen_action = sampled_from(vec![Action::NextFeat, Action::NextThreshold, Action::NextNode, Action::SelectNode]);
        tc.draw(gen_vec(gen_action, seq_len))
    }

    #[hegel::composite]
    fn gen_decision_actions(tc: TestCase, feat_ids: Option<&[String]>, allow_refs: Option<bool>) -> DecisionActions {
        let feat_order = feat_ids.map(|ids| ids.to_vec()).unwrap_or_else(|| {
            let n_feats = tc.draw(gen_usize_between(1, 4));
            tc.draw(gen_vec(gen_text(), n_feats))
        });

        let thresholds = tc.draw(gen_thresholds(&feat_order));
        let sub_actions = tc.draw(gen_sub_actions());

        let meta_actions = tc.draw(gen_meta_actions(&sub_actions));
        let n_thresholds = tc.draw(gen_usize_between(1, 10));
        let refs_allowed = allow_refs.unwrap_or_else(|| tc.draw(booleans()));

        DecisionActions { meta_actions, thresholds, feat_order, n_thresholds, allow_refs: refs_allowed }
    }

    #[hegel::composite]
    fn gen_state_for(tc: TestCase, actions: &DecisionActions, n_nodes: usize) -> ActionsState {
        tc.draw(gen_actions_state(n_nodes, actions.feat_order.len(), actions.n_thresholds, 1))
    }

    mod do_set_feat_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            new_feat_id: Option<String>,
            prev_feat_id: Option<String>,
            feat_id: Option<String>,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_ref_node: Option<bool>, draw_invalid: bool) -> TestContext {
            let actions = tc.draw(gen_decision_actions(None, None));
            let mut net = tc.draw(gen_decision_net(Some(false), Some(&actions.feat_order), None));
            let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

            let draw_invalid_feat_idx = if draw_invalid { tc.draw(booleans()) } else { false };
            let draw_invalid_node_idx = if draw_invalid {
                if draw_invalid_feat_idx { tc.draw(booleans()) } else { true }
            } else { false };

            if draw_invalid_feat_idx {
                state.feat_idx = tc.draw(gen_usize_with_min(actions.feat_order.len()));
            }
            if draw_invalid_node_idx {
                state.node_idx = tc.draw(gen_usize_with_min(net.nodes.len()));
            }

            let mut prev_feat_id = None;
            let node_idx = state.node_idx;
            let valid_node_idx = !draw_invalid_node_idx;
            if valid_node_idx {
                net.nodes[node_idx] = if draw_ref_node.unwrap_or_else(|| tc.draw(booleans())) {
                    let ref_node = tc.draw(gen_ref_node(net.nodes.len(), None, None, None));
                    DecisionNode::Ref(ref_node)
                } else {
                    let branch_node = tc.draw(gen_branch_node(net.nodes.len(), None, None, None, None, None));
                    prev_feat_id = branch_node.feat_id.clone();
                    DecisionNode::Branch(branch_node)
                };
            }

            let new_feat_id = if draw_invalid_feat_idx { None } else { Some(actions.feat_order[state.feat_idx].clone()) };

            let result = DecisionActionsDepsImpl.do_set_feat(&actions, &state, &mut net);
            let feat_id = if valid_node_idx && let DecisionNode::Branch(branch_node) = &net.nodes[node_idx] { branch_node.feat_id.clone() } else { None };

            TestContext { new_feat_id, prev_feat_id, feat_id, result }
        }

        #[hegel::test]
        fn test_do_set_feat(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(false), false));
            assert_eq!(ctx.feat_id, ctx.new_feat_id);
        }

        #[hegel::test]
        fn test_do_set_feat_ref(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(true), false));
            assert_eq!(ctx.feat_id, ctx.prev_feat_id);
        }

        #[hegel::test]
        fn test_do_set_feat_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(None, true));
            assert!(ctx.result.is_err());
        }
    }

    mod do_set_threshold_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            new_threshold: f64,
            prev_threshold: Option<f64>,
            threshold: Option<f64>,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, maybe_draw_ref_or_no_feat: Option<bool>, draw_invalid: bool) -> TestContext {
            let actions = tc.draw(gen_decision_actions(None, None));
            let mut net = tc.draw(gen_decision_net(Some(false), Some(&actions.feat_order), None));
            let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

            let draw_invalid_node_idx = if draw_invalid { tc.draw(booleans()) } else { false };
            let draw_invalid_feat_id = if draw_invalid { !draw_invalid_node_idx } else { false };

            if draw_invalid_node_idx {
                state.node_idx = tc.draw(gen_usize_with_min(net.nodes.len()));
            }

            let draw_ref_or_no_feat = !draw_invalid_feat_id && maybe_draw_ref_or_no_feat.unwrap_or_else(|| tc.draw(booleans()));
            let draw_ref_node = if draw_ref_or_no_feat { tc.draw(booleans()) } else { false };
            let draw_no_feat_id = if draw_ref_or_no_feat { !draw_ref_node } else { false };

            let mut prev_threshold = None;
            let node_idx = state.node_idx;
            if !draw_invalid_node_idx {
                net.nodes[node_idx] = if draw_ref_node {
                    let ref_node = tc.draw(gen_ref_node(net.nodes.len(), None, None, None));
                    DecisionNode::Ref(ref_node)
                } else {
                    let feat_ids = vec![if draw_invalid_feat_id {
                        let invalid_feat_id = tc.draw(gen_text());
                        tc.assume(!actions.thresholds.contains_key(&invalid_feat_id));
                        invalid_feat_id
                    } else {
                        tc.draw(sampled_from(actions.feat_order.clone()))
                    }];
                    let branch_node = tc.draw(gen_branch_node(net.nodes.len(), None, Some(&feat_ids), Some(!draw_no_feat_id), None, None));
                    prev_threshold = branch_node.threshold;
                    DecisionNode::Branch(branch_node)
                };
            }

            let new_threshold = tc.draw(gen_f64());
            let mut mock_deps = MockDecisionActionsDeps::new();

            let value_at_count = usize::from(!draw_invalid && !draw_ref_or_no_feat);
            let value_at_dep = mock_deps.expect_value_at().times(value_at_count);
            value_at_dep.return_const(new_threshold);

            let result = actions._do_set_threshold(&mock_deps, &state, &mut net);
            let threshold = if !draw_invalid && let DecisionNode::Branch(branch_node) = &net.nodes[node_idx] { branch_node.threshold } else { None };

            TestContext { new_threshold, prev_threshold, threshold, result }
        }

        #[hegel::test]
        fn test_do_set_threshold(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(false), false));
            assert_eq!(ctx.threshold, Some(ctx.new_threshold));
        }

        #[hegel::test]
        fn test_do_set_threshold_ref_or_no_feat(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(true), false));
            assert_eq!(ctx.threshold, ctx.prev_threshold);
        }

        #[hegel::test]
        fn test_do_set_threshold_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(None, true));
            assert!(ctx.result.is_err());
        }
    }

    mod do_set_true_idx_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            selected_idx: usize,
            true_idx: Option<usize>,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let actions = tc.draw(gen_decision_actions(None, None));
            let mut net = tc.draw(gen_decision_net(Some(false), Some(&actions.feat_order), None));
            let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

            if draw_invalid {
                state.node_idx = tc.draw(gen_usize_with_min(net.nodes.len()));
            }

            let result = DecisionActionsDepsImpl.do_set_true_idx(&state, &mut net);
            let true_idx = if draw_invalid { None } else { net.nodes[state.node_idx].true_idx() };

            TestContext { selected_idx: state.selected_idx, true_idx, result }
        }

        #[hegel::test]
        fn test_do_set_true_idx(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.true_idx, Some(ctx.selected_idx));
        }

        #[hegel::test]
        fn test_do_set_true_idx_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod do_set_false_idx_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            selected_idx: usize,
            false_idx: Option<usize>,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let actions = tc.draw(gen_decision_actions(None, None));
            let mut net = tc.draw(gen_decision_net(Some(false), Some(&actions.feat_order), None));
            let mut state = tc.draw(gen_state_for(&actions, net.nodes.len()));

            if draw_invalid {
                state.node_idx = tc.draw(gen_usize_with_min(net.nodes.len()));
            }

            let result = DecisionActionsDepsImpl.do_set_false_idx(&state, &mut net);
            let false_idx = if draw_invalid { None } else { net.nodes[state.node_idx].false_idx() };

            TestContext { selected_idx: state.selected_idx, false_idx, result }
        }

        #[hegel::test]
        fn test_do_set_false_idx(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.false_idx, Some(ctx.selected_idx));
        }

        #[hegel::test]
        fn test_do_set_false_idx_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod do_set_ref_idx_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            selected_idx: usize,
            prev_node: Option<DecisionNode>,
            node: Option<DecisionNode>,
            ref_idx: Option<usize>,
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_branch_node: Option<bool>, draw_invalid: bool) -> TestContext {
            let actions = tc.draw(gen_decision_actions(None, None));
            let mut net = tc.draw(gen_decision_net(Some(false), Some(&actions.feat_order), None));
            let n_nodes = net.nodes.len();
            let mut state = tc.draw(gen_state_for(&actions, n_nodes));

            if draw_invalid {
                state.node_idx = tc.draw(gen_usize_with_min(n_nodes));
            }

            let node_idx = state.node_idx;
            let valid_node_idx = !draw_invalid;
            if valid_node_idx {
                net.nodes[node_idx] = if draw_branch_node.unwrap_or_else(|| tc.draw(booleans())) {
                    let branch_node = tc.draw(gen_branch_node(n_nodes, None, None, None, None, None));
                    DecisionNode::Branch(branch_node)
                } else {
                    let ref_node = tc.draw(gen_ref_node(n_nodes, None, None, None));
                    DecisionNode::Ref(ref_node)
                };
            }

            let prev_node = if valid_node_idx { Some(net.nodes[node_idx].clone()) } else { None };

            let result = DecisionActionsDepsImpl.do_set_ref_idx(&state, &mut net);

            let node = if valid_node_idx { Some(net.nodes[node_idx].clone()) } else { None };
            let ref_idx = if valid_node_idx && let DecisionNode::Ref(ref_node) = &net.nodes[node_idx] { ref_node.ref_idx } else { None };

            TestContext { selected_idx: state.selected_idx, prev_node, node, ref_idx, result }
        }

        #[hegel::test]
        fn test_do_set_ref_idx(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(false), false));
            assert_eq!(ctx.ref_idx, Some(ctx.selected_idx));
        }

        #[hegel::test]
        fn test_do_set_ref_idx_branch(tc: TestCase) {
            let ctx = tc.draw(gen_context(Some(true), false));
            assert_eq!(ctx.node, ctx.prev_node);
        }

        #[hegel::test]
        fn test_do_set_ref_idx_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(None, true));
            assert!(ctx.result.is_err());
        }
    }

    #[hegel::test]
    fn test_do_new_branch(tc: TestCase) {
        let mut net = tc.draw(gen_decision_net(None, None, None));
        let n_nodes = net.nodes.len();

        DecisionActionsDepsImpl.do_new_branch(&mut net);

        assert_eq!(net.nodes.len(), n_nodes + 1);
        let DecisionNode::Branch(new_node) = &net.nodes[n_nodes] else {
            panic!("expected a branch node")
        };
        assert_eq!(new_node.threshold, None);
        assert_eq!(new_node.feat_id, None);
        assert_eq!(new_node.true_idx, None);
        assert_eq!(new_node.false_idx, None);
        assert!(!new_node.value);
    }

    mod do_new_ref_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            prev_nodes: Vec<DecisionNode>,
            nodes: Vec<DecisionNode>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, allow_refs: bool) -> TestContext {
            let actions = tc.draw(gen_decision_actions(None, Some(allow_refs)));
            let mut net = tc.draw(gen_decision_net(None, None, None));
            let prev_nodes = net.nodes.clone();

            DecisionActionsDepsImpl.do_new_ref(&actions, &mut net);

            TestContext { prev_nodes, nodes: net.nodes }
        }

        #[hegel::test]
        fn test_do_new_ref(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            let n_nodes = ctx.prev_nodes.len();
            assert_eq!(ctx.nodes.len(), n_nodes + 1);
            let DecisionNode::Ref(new_node) = &ctx.nodes[n_nodes] else {
                panic!("expected a ref node")
            };
            assert_eq!(new_node.ref_idx, None);
            assert_eq!(new_node.true_idx, None);
            assert_eq!(new_node.false_idx, None);
            assert!(!new_node.value);
        }

        #[hegel::test]
        fn test_do_new_ref_blocked(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.nodes, ctx.prev_nodes);
        }
    }
}
