use std::collections::{HashMap, HashSet};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use crate::features::features::Feature;
use crate::network::network::Network;
use crate::utils::parse_json;

#[derive(Hash, PartialEq, Eq, Clone, Copy, Debug, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Action {
    NextFeat, NextThreshold, NextNode, SelectNode, NextGate, SetFeatIdx, SetThreshold, SetGate, SetIn1Idx, SetIn2Idx, SetTrueIdx, SetFalseIdx, SetRefIdx, NewInput, NewGate, NewBranch, NewRef
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
        actions.do_action(&mut net, &mut state, *action);
    }

    net
}

#[derive(Deserialize)]
pub struct MetaActionEntry {
    pub label: Action,
    pub sub_actions: Vec<Action>
}

#[derive(Deserialize)]
pub struct ThresholdEntry {
    pub feat_id: String,
    pub min: f64,
    pub max: f64
}

pub fn parse_meta_actions(json: &Value) -> Result<HashMap<Action, Vec<Action>>, String> {
    let entries = parse_json::<Vec<MetaActionEntry>>(json)?;

    let mut meta_actions = HashMap::new();
    let mut labels = Vec::new();
    let mut all_sub_actions = Vec::new();

    for entry in entries {
        labels.push(entry.label);
        all_sub_actions.extend_from_slice(&entry.sub_actions);
        meta_actions.insert(entry.label, entry.sub_actions);
    }

    let labels_set = labels.into_iter().collect::<HashSet<Action>>();
    let sub_set = all_sub_actions.into_iter().collect::<HashSet<Action>>();

    if !labels_set.is_disjoint(&sub_set) {
        return Err("sub action cannot be a meta action".to_string());
    }

    Ok(meta_actions)
}

pub fn parse_thresholds(json_value: &Value, feats: &[Box<dyn Feature>]) -> Result<Vec<ThresholdRange>, String> {
    let entries = parse_json::<Vec<ThresholdEntry>>(json_value)?;

    let n_features = feats.len();

    if entries.len() != n_features {
        return Err("length of thresholds must be == # of features".to_string());
    }

    let mut thresholds = vec![ThresholdRange { min: 0.0, max: 0.0 }; n_features];

    for entry in entries {
        let maybe_idx = feats.iter().position(|feat| feat.id() == entry.feat_id);
        
        let idx = maybe_idx.ok_or_else(|| format!("feature with id \"{}\" not found", entry.feat_id))?;

        if entry.max <= entry.min {
            return Err(format!("threshold for feature id \"{}\" max must be > min", entry.feat_id));
        }

        thresholds[idx] = ThresholdRange { 
            min: entry.min, 
            max: entry.max 
        };
    }

    Ok(thresholds)
}
