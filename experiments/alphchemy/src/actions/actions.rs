use std::collections::{HashMap, HashSet};
use serde::{Deserialize, Serialize, Serializer};
use serde_json::Value;
use crate::features::features::{Feature, feat_ids};
use crate::network::network::Network;
use crate::utils::parse_json;

#[derive(Hash, PartialEq, Eq, Clone, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Action {
    NextFeat, NextThreshold, NextNode, SelectNode, NextGate, SetFeat, SetThreshold, SetGate, SetIn1Idx, SetIn2Idx, SetTrueIdx, SetFalseIdx, SetRefIdx, NewInput, NewGate, NewBranch, NewRef,
    #[serde(skip)]
    MetaAction(String)
}

impl Action {
    pub fn label(&self) -> &str {
        match self {
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
        }
    }
}

impl Serialize for Action {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer
    {
        serializer.serialize_str(self.label())
    }
}


#[derive(Clone, Debug)]
pub struct ThresholdRange {
    pub min: f64,
    pub max: f64
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

#[derive(Deserialize)]
pub struct MetaActionEntry {
    pub label: String,
    pub sub_actions: Vec<Action>
}

#[derive(Deserialize)]
pub struct ThresholdEntry {
    pub feat_id: String,
    pub min: f64,
    pub max: f64
}

pub fn parse_meta_actions(json: &Value) -> Result<HashMap<String, Vec<Action>>, String> {
    let entries = parse_json::<Vec<MetaActionEntry>>(json)?;

    let mut meta_actions = HashMap::new();

    for entry in entries {
        meta_actions.insert(entry.label, entry.sub_actions);
    }

    Ok(meta_actions)
}

pub fn parse_thresholds(json_value: &Value, feats: &[Box<dyn Feature>]) -> Result<HashMap<String, ThresholdRange>, String> {
    let entries = parse_json::<Vec<ThresholdEntry>>(json_value)?;
    let expected_feat_ids = feat_ids(feats);
    let expected_feat_set = expected_feat_ids.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();

    if entries.len() != expected_feat_ids.len() {
        return Err("length of thresholds must be == # of features".to_string());
    }

    let mut thresholds = HashMap::new();

    for entry in entries {
        let feat_id = entry.feat_id;

        if !expected_feat_set.contains(feat_id.as_str()) {
            return Err(format!("feature with id \"{}\" not found", feat_id));
        }

        if thresholds.contains_key(&feat_id) {
            return Err(format!("duplicate threshold for feature id \"{}\"", feat_id));
        }

        if entry.max <= entry.min {
            return Err(format!("threshold for feature id \"{}\" max must be > min", feat_id));
        }

        let range = ThresholdRange {
            min: entry.min,
            max: entry.max
        };
        thresholds.insert(feat_id, range);
    }

    Ok(thresholds)
}

pub fn validate_feat_order(feat_order: &[String], feats: &[Box<dyn Feature>]) -> Result<(), String> {
    let expected_feat_ids = feat_ids(feats);
    let expected_feat_set = expected_feat_ids.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();
    let feat_order_set = feat_order.iter().map(|feat_id| feat_id.as_str()).collect::<HashSet<&str>>();

    if feat_order.len() != expected_feat_ids.len() {
        return Err("feat_order length must be == # of features".to_string());
    }

    if feat_order_set.len() != feat_order.len() {
        return Err("feat_order cannot contain duplicate feature ids".to_string());
    }

    if feat_order_set != expected_feat_set {
        return Err("feat_order must contain every feature id exactly once".to_string());
    }

    Ok(())
}
