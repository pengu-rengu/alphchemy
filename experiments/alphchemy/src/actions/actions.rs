use crate::network::network::Network;

#[derive(Hash, PartialEq, Eq, Clone, Copy, Debug)]
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
        self.min + (self.max - self.min) * idx as f64 / (n_thresholds - 1) as f64
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
        extra_idx: 0,
    };

    for action in action_seq {
        actions.do_action(&mut net, &mut state, *action);
    }

    net
}
