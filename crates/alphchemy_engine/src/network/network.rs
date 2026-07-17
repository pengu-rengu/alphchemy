use serde::Serialize;
use serde_json::Value;
use crate::features::features::TimestampedTable;

#[derive(Clone, Copy, Debug, Serialize, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum Anchor { FromStart, FromEnd }

#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct NodePtr {
    pub anchor: Anchor,
    pub offset: usize
}

impl NodePtr {
    pub fn abs_idx(&self, len: usize) -> Option<usize> {
        if self.offset >= len {
            return None;
        }

        match self.anchor {
            Anchor::FromStart => Some(self.offset),
            Anchor::FromEnd => Some(len - 1 - self.offset)
        }
    }
}

pub trait Network {
    fn to_json(&self) -> Value;
    fn reset_state(&mut self);
    fn eval(&mut self, feat_table: &TimestampedTable, row_idx: usize);
    fn node_value(&self, node_ptr: &NodePtr) -> bool;
}

pub trait Penalties<N: Network> {
    fn to_json(&self) -> Value;
    fn penalty(&self, net: &N, n_feats: usize) -> f64;
}

pub fn feats_penalty_from_counts(n_used: usize, n_feats: usize, used_feat_penalty: f64, unused_feat_penalty: f64) -> f64 {
    let n_unused = n_feats - n_used;
    let used_penalty = used_feat_penalty * n_used as f64;
    let unused_penalty = unused_feat_penalty * n_unused as f64;

    used_penalty + unused_penalty
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use crate::test_utils::{gen_f64, gen_usize, gen_usize_with_max, gen_usize_with_min};
    use hegel::{TestCase, generators::sampled_from};

    #[hegel::composite]
    pub fn gen_node_ptr(tc: TestCase, len: usize, anchor: Option<Anchor>, overflow: bool) -> NodePtr {
        let anchor = anchor.unwrap_or_else(|| {
            tc.draw(sampled_from(vec![Anchor::FromStart, Anchor::FromEnd]))
        });

        let offset = if overflow {
            tc.draw(gen_usize_with_min(len))
        } else {
            tc.draw(gen_usize_with_max(len - 1))
        };

        NodePtr { anchor, offset }
    }

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
    fn test_node_ptr(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(1));
        let ptr_from_start = tc.draw(gen_node_ptr(len, Some(Anchor::FromStart), false));
        let ptr_from_end = tc.draw(gen_node_ptr(len, Some(Anchor::FromEnd), false));
        let overflow_from_start = tc.draw(gen_node_ptr(len, Some(Anchor::FromStart), true));
        let overflow_from_end = tc.draw(gen_node_ptr(len, Some(Anchor::FromEnd), true));

        let from_start_idx = ptr_from_start.abs_idx(len);
        let from_end_idx = ptr_from_end.abs_idx(len);

        let overflow_from_start_idx = overflow_from_start.abs_idx(len);
        let overflow_from_end_idx = overflow_from_end.abs_idx(len);

        assert_eq!(from_start_idx, Some(ptr_from_start.offset));
        assert_eq!(from_end_idx, Some(len - 1 - ptr_from_end.offset));
        assert_eq!(overflow_from_start_idx, None);
        assert_eq!(overflow_from_end_idx, None);
    }
}
