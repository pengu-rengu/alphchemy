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
}
