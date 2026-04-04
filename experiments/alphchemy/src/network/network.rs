use std::fmt::Debug;
use serde::Deserialize;
use crate::features::features::FeatTable;

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Anchor { FromStart, FromEnd }

#[derive(Clone, Debug, Deserialize)]
pub struct NodePtr {
    pub anchor: Anchor,
    pub idx: usize
}

impl NodePtr {
    pub fn abs_idx(&self, len: usize) -> usize {
        match self.anchor {
            Anchor::FromStart => self.idx,
            Anchor::FromEnd => len - self.idx - 1
        }
    }
}

pub trait Network: Debug {
    fn reset_state(&mut self);
    fn eval(&mut self, feat_table: &FeatTable, row_idx: usize);
    fn node_value(&self, node_ptr: &NodePtr) -> bool;
}

pub trait Penalties<N: Network> {
    fn penalty(&self, net: &N, n_feats: usize) -> f64;
}

pub fn feats_penalty_from_counts(n_used: usize, n_feats: usize, used_feat_penalty: f64, unused_feat_penalty: f64) -> f64 {
    let n_unused = n_feats.saturating_sub(n_used);
    let used_penalty = used_feat_penalty * n_used as f64;
    let unused_penalty = unused_feat_penalty * n_unused as f64;

    used_penalty + unused_penalty
}
