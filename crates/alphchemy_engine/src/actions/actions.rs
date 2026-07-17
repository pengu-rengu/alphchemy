use std::collections::HashMap;
use serde::{Serialize, Serializer};
use serde_json::{json, Value};
use crate::network::network::Network;

#[derive(Hash, PartialEq, Eq, Clone, Debug)]
pub enum Action {
    NextFeat, NextThreshold, NextNode, SelectNode, NextGate, SetFeat, SetThreshold, SetGate, SetIn1Idx, SetIn2Idx, SetTrueIdx, SetFalseIdx, SetRefIdx, NewInput, NewGate, NewBranch, NewRef,
    MetaAction(String)
}

impl Serialize for Action {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer
    {   
        let label = match self {
            Action::NextFeat => "next_feat",
            Action::NextThreshold => "next_threshold",
            Action::NextNode => "next_node",
            Action::SelectNode => "select_node",
            Action::NextGate => "next_gate",
            Action::SetFeat => "set_feat",
            Action::SetThreshold => "set_threshold",
            Action::SetGate => "set_gate",
            Action::SetIn1Idx => "set_in1_idx",
            Action::SetIn2Idx => "set_in2_idx",
            Action::SetTrueIdx => "set_true_idx",
            Action::SetFalseIdx => "set_false_idx",
            Action::SetRefIdx => "set_ref_idx",
            Action::NewInput => "new_input",
            Action::NewGate => "new_gate",
            Action::NewBranch => "new_branch",
            Action::NewRef => "new_ref",
            Action::MetaAction(label) => label
        };
        serializer.serialize_str(label)
    }
}


#[derive(Clone, Debug)]
pub struct ThresholdRange {
    pub min: f64,
    pub max: f64
}

// Meta-actions map -> array of {label, sub_actions}, sorted by label for determinism.
pub fn meta_actions_json(meta_actions: &HashMap<String, Vec<Action>>) -> Value {
    let mut labels = meta_actions.keys().collect::<Vec<&String>>();
    labels.sort();
    let items = labels.iter().map(|label| json!({"label": label, "sub_actions": meta_actions[*label]})).collect::<Vec<Value>>();
    Value::Array(items)
}

// Thresholds map -> array of {feat_id, min, max}, ordered by feat_order for determinism.
pub fn thresholds_json(thresholds: &HashMap<String, ThresholdRange>, feat_order: &[String]) -> Value {
    let to_entry = |feat_id: &String| thresholds.get(feat_id).map(|range| json!({"feat_id": feat_id, "min": range.min, "max": range.max}));
    let items = feat_order.iter().filter_map(to_entry).collect::<Vec<Value>>();
    Value::Array(items)
}

impl ThresholdRange {
    pub fn value_at(&self, idx: usize, n_thresholds: usize) -> f64 {
        if n_thresholds <= 1 {
            return self.min;
        }
        let range = self.max - self.min;
        let denom = (n_thresholds - 1) as f64;
        let fraction = idx as f64 / denom;
        let offset = range * fraction;
        self.min + offset
    }
}

#[derive(Clone, Debug)]
pub struct ActionsState {
    pub feat_idx: usize,
    pub node_idx: usize,
    pub selected_idx: usize,
    pub threshold_idx: usize,
    pub extra_idx: usize
}

impl ActionsState {
    pub fn next_feat(&mut self, n_feats: usize) {
        self.feat_idx += 1;
        if self.feat_idx >= n_feats {
            self.feat_idx = 0;
        }
    }

    pub fn next_threshold(&mut self, n_thresholds: usize) {
        self.threshold_idx += 1;
        if self.threshold_idx >= n_thresholds {
            self.threshold_idx = 0;
        }
    }

    pub fn next_node(&mut self, n_nodes: usize) {
        self.node_idx += 1;
        if self.node_idx >= n_nodes {
            self.node_idx = 0;
        }
    }

    pub fn select_node(&mut self) {
        self.selected_idx = self.node_idx;
    }
}

pub trait Actions<N: Network> {
    fn to_json(&self) -> Value;
    fn actions_list(&self) -> Vec<Action>;
    fn do_action(&self, net: &mut N, state: &mut ActionsState, action: Action);
}

pub fn construct_net<N: Network + Clone, A: Actions<N>>(base_net: &N, action_seq: &[Action], actions: &A) -> N {
    let mut net = base_net.clone();

    let mut state = ActionsState {
        feat_idx: 0,
        node_idx: 0,
        selected_idx: 0,
        threshold_idx: 0,
        extra_idx: 0
    };

    for action in action_seq {
        actions.do_action(&mut net, &mut state, action.clone());
    }

    net
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use approx::assert_relative_eq;
    use hegel::TestCase;
    use hegel::generators::sampled_from;
    use crate::test_utils::{gen_f64, gen_f64_with_min, gen_text, gen_usize_with_max, gen_vec};

    #[hegel::composite]
    pub fn gen_threshold_range(tc: TestCase) -> ThresholdRange {
        let min = tc.draw(gen_f64());
        let max = tc.draw(gen_f64_with_min(min));

        ThresholdRange { min, max }
    }

    #[hegel::composite]
    pub fn gen_thresholds(tc: TestCase, feat_ids: &[String]) -> HashMap<String, ThresholdRange> {
        let mut thresholds = HashMap::new();

        for feat_id in feat_ids {
            let range = tc.draw(gen_threshold_range());
            thresholds.insert(feat_id.clone(), range);
        }

        thresholds
    }

    #[hegel::composite]
    pub fn gen_actions_state(tc: TestCase, n_nodes: usize, n_feats: usize, n_thresholds: usize, n_extras: usize) -> ActionsState {
        ActionsState {
            feat_idx: tc.draw(gen_usize_with_max(n_feats - 1)),
            node_idx: tc.draw(gen_usize_with_max(n_nodes - 1)),
            selected_idx: tc.draw(gen_usize_with_max(n_nodes - 1)),
            threshold_idx: tc.draw(gen_usize_with_max(n_thresholds - 1)),
            extra_idx: tc.draw(gen_usize_with_max(n_extras - 1))
        }
    }

    #[hegel::composite]
    pub fn gen_meta_actions(tc: TestCase, sub_actions: &[Action]) -> HashMap<String, Vec<Action>> {
        let n_labels = tc.draw(gen_usize_with_max(3));
        let labels = tc.draw(gen_vec(gen_text(), n_labels));
        let mut meta_actions = HashMap::new();

        for label in labels {
            let seq_len = tc.draw(gen_usize_with_max(2)) + 1;
            let seq = tc.draw(gen_vec(sampled_from(sub_actions), seq_len));
            meta_actions.insert(label, seq);
        }

        meta_actions
    }

    #[hegel::test]
    fn test_value_at(tc: TestCase) {
        let range = tc.draw(gen_threshold_range());
        let n_thresholds = tc.draw(gen_usize_with_max(20)) + 2;

        let at_min = range.value_at(0, n_thresholds);
        assert_relative_eq!(at_min, range.min, epsilon = 1e-5);

        let at_max = range.value_at(n_thresholds - 1, n_thresholds);
        assert_relative_eq!(at_max, range.max, epsilon = 1e-5);

        let guarded_zero = range.value_at(3, 0);
        assert_relative_eq!(guarded_zero, range.min, epsilon = 1e-5);

        let guarded_one = range.value_at(3, 1);
        assert_relative_eq!(guarded_one, range.min, epsilon = 1e-5);

        let mid = range.value_at(1, n_thresholds);
        assert!(mid >= range.min);
        assert!(mid <= range.max);
    }

    #[hegel::test]
    fn test_actions_state_transitions(tc: TestCase) {
        let n_feats = tc.draw(gen_usize_with_max(8)) + 2;
        let n_thresholds = tc.draw(gen_usize_with_max(8)) + 2;
        let n_nodes = tc.draw(gen_usize_with_max(8)) + 2;
        let mut state = tc.draw(gen_actions_state(n_nodes, n_feats, n_thresholds, 1));

        state.feat_idx = n_feats - 1;
        state.next_feat(n_feats);
        assert_eq!(state.feat_idx, 0);

        state.threshold_idx = n_thresholds - 1;
        state.next_threshold(n_thresholds);
        assert_eq!(state.threshold_idx, 0);

        state.node_idx = n_nodes - 2;
        state.next_node(n_nodes);
        assert_eq!(state.node_idx, n_nodes - 1);

        state.select_node();
        assert_eq!(state.selected_idx, state.node_idx);
    }

    #[hegel::test]
    fn test_action_serialize(tc: TestCase) {
        let next_feat = serde_json::to_value(Action::NextFeat).unwrap();
        assert_eq!(next_feat, json!("next_feat"));

        let set_gate = serde_json::to_value(Action::SetGate).unwrap();
        assert_eq!(set_gate, json!("set_gate"));

        let new_ref = serde_json::to_value(Action::NewRef).unwrap();
        assert_eq!(new_ref, json!("new_ref"));

        let label = tc.draw(gen_text());
        let label_copy = label.clone();
        let meta = Action::MetaAction(label);
        let meta_value = serde_json::to_value(meta).unwrap();
        assert_eq!(meta_value, json!(label_copy));
    }

    #[hegel::test]
    fn test_meta_actions_json(tc: TestCase) {
        let sub_actions = vec![Action::NextFeat, Action::SetFeat, Action::NewGate];
        let meta_actions = tc.draw(gen_meta_actions(&sub_actions));
        let value = meta_actions_json(&meta_actions);

        let items = value.as_array().unwrap();
        assert_eq!(items.len(), meta_actions.len());

        let mut prev_label = String::new();
        for item in items {
            let label = item["label"].as_str().unwrap();
            assert!(label >= prev_label.as_str());
            assert!(item["sub_actions"].is_array());
            prev_label = label.to_string();
        }

        let empty = meta_actions_json(&HashMap::new());
        assert_eq!(empty, json!([]));
    }

    #[hegel::test]
    fn test_thresholds_json(tc: TestCase) {
        let n_feats = tc.draw(gen_usize_with_max(4)) + 1;
        let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));
        let thresholds = tc.draw(gen_thresholds(&feat_ids));

        let mut feat_order = feat_ids.clone();
        feat_order.push("absent_feat".to_string());

        let value = thresholds_json(&thresholds, &feat_order);
        let items = value.as_array().unwrap();
        assert_eq!(items.len(), feat_ids.len());

        for (idx, feat_id) in feat_ids.iter().enumerate() {
            let entry = &items[idx];
            assert_eq!(entry["feat_id"].as_str().unwrap(), feat_id.as_str());
            assert!(entry["min"].is_number());
            assert!(entry["max"].is_number());
        }
    }
}
