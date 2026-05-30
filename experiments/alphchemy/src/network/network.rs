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
    use crate::test_utils::{gen_f64, gen_usize, gen_usize_with_min};
    use hegel::TestCase;

    #[hegel::test]
    fn test_feats_penalty_from_counts(tc: TestCase) {
        let n_used = tc.draw(gen_usize());
        let n_unused = tc.draw(gen_usize());
        let used_penalty = tc.draw(gen_f64());
        let unused_penalty = tc.draw(gen_f64());

        let penalty = feats_penalty_from_counts(n_used, n_used + n_unused, used_penalty, unused_penalty);

        let used_count = n_used as f64;
        let unused_count = n_unused as f64;
        let expected_used_penalty = used_count * used_penalty;
        let expected_unused_penalty = unused_count * unused_penalty;

        assert_eq!(penalty, expected_used_penalty + expected_unused_penalty);
    }

    #[hegel::test]
    fn test_node_ptr_some(tc: TestCase) {
        let idx = tc.draw(gen_usize());
        let len = tc.draw(gen_usize_with_min(idx)) + 1;
        
        let abs_idx_from_start = NodePtr {
            anchor: Anchor::FromStart,
            idx
        }.abs_idx(len);

        assert_eq!(abs_idx_from_start, Some(idx));

        let abs_idx_from_end = NodePtr {
            anchor: Anchor::FromEnd,
            idx
        }.abs_idx(len);

        assert_eq!(abs_idx_from_end, Some(len - 1 - idx))
    }

    #[hegel::test]
    fn test_node_ptr_none(tc: TestCase) {
        let len = tc.draw(gen_usize());
        let idx = tc.draw(gen_usize_with_min(len));

        let abs_idx_from_start = NodePtr {
            anchor: Anchor::FromStart,
            idx
        }.abs_idx(len);

        assert_eq!(abs_idx_from_start, None);

        let abs_idx_from_end = NodePtr {
            anchor: Anchor::FromEnd,
            idx
        }.abs_idx(len);

        assert_eq!(abs_idx_from_end, None);
    }
}
