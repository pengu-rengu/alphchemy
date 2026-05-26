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
    pub fn abs_idx(&self, len: usize) -> Option<usize> {
        if self.idx >= len {
            return None;
        }

        match self.anchor {
            Anchor::FromStart => Some(self.idx),
            Anchor::FromEnd => Some(len - 1 - self.idx)
        }
    }
}

pub trait Network {
    fn reset_state(&mut self);
    fn eval(&mut self, feat_table: &FeatTable, row_idx: usize);
    fn node_value(&self, node_ptr: &NodePtr) -> bool;
}

pub trait Penalties<N: Network> {
    fn penalty(&self, net: &N, n_feats: usize) -> f64;
}

pub fn feats_penalty_from_counts(n_used: usize, n_feats: usize, used_feat_penalty: f64, unused_feat_penalty: f64) -> f64 {
    let n_unused = n_feats - n_used;
    let used_penalty = used_feat_penalty * n_used as f64;
    let unused_penalty = unused_feat_penalty * n_unused as f64;

    used_penalty + unused_penalty
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    proptest! {

        #[test]
        fn test_feats_penalty_from_counts(
            n_used in 0usize..100usize,
            n_unused in 0usize..100usize,
            used_penalty in any::<f64>(),
            unused_penalty in any::<f64>()
        ) {
            
            let penalty = feats_penalty_from_counts(n_used, n_used + n_unused, used_penalty, unused_penalty);

            let expected_used_penalty = n_used as f64 * used_penalty;
            let expected_unused_penalty = n_unused as f64 * unused_penalty;

            prop_assert_eq!(penalty, expected_used_penalty + expected_unused_penalty);
        }

        #[test]
        fn test_node_ptr(anchor in prop_oneof![Just(Anchor::FromStart), Just(Anchor::FromEnd)]) {
            let a = anchor;
            
        }
    }
}
