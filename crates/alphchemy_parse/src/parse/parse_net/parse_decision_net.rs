use std::collections::HashSet;

use alphchemy_engine::network::decision_net::{DecisionNet, DecisionNode, BranchNode, RefNode, DecisionPenalties};
use crate::utils::expect_non_neg;
use super::super::parse::Fields;

#[cfg(test)]
use mockall::automock;

const MAX_TRAIL_LEN: usize = 25;

#[cfg_attr(test, automock)]
trait ParseDecisionNetDeps {
    fn string<'a>(&self, fields: &Fields, keys: &[&'a str], default: &str) -> Result<String, String> {
        fields.string(keys, default)
    }

    fn option_string<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Result<Option<String>, String> {
        fields.option_string(keys)
    }

    fn option_f64<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Result<Option<f64>, String> {
        fields.option_f64(keys)
    }

    fn option_usize<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Result<Option<usize>, String> {
        fields.option_usize(keys)
    }

    fn bool<'a>(&self, fields: &Fields, keys: &[&'a str], default: bool) -> Result<bool, String> {
        fields.bool(keys, default)
    }

    fn usize<'a>(&self, fields: &Fields, keys: &[&'a str], default: usize) -> Result<usize, String> {
        fields.usize(keys, default)
    }

    fn child_fields<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Result<Option<Fields>, String> {
        fields.child_fields(keys)
    }

    fn indexed_nodes_fields(&self, fields: Option<Fields>) -> Result<Vec<Fields>, String> {
        super::parse_net::indexed_node_fields(fields)
    }

    fn feat_id_set(&self, feat_ids: &[String]) -> HashSet<String> {
        feat_ids.iter().cloned().collect()
    }

    fn validate_idx(&self, idx: Option<usize>, n_nodes: usize, field: &str) -> Result<(), String> {
        super::parse_net::validate_idx(idx, n_nodes, field)
    }

    fn parse_branch_node(&self, fields: &Fields) -> Result<BranchNode, String> {
        _parse_branch_node(&ParseDecisionNetDepsImpl, fields)
    }

    fn parse_ref_node(&self, fields: &Fields) -> Result<RefNode, String> {
        _parse_ref_node(&ParseDecisionNetDepsImpl, fields)
    }

    fn parse_decision_node(&self, fields: &Fields) -> Result<DecisionNode, String> {
        _parse_decision_node(&ParseDecisionNetDepsImpl, fields)
    }

    fn validate_branch_node(&self, branch: &BranchNode, ids: &HashSet<String>, n_nodes: usize) -> Result<(), String> {
        _validate_branch_node(&ParseDecisionNetDepsImpl, branch, ids, n_nodes)
    }

    fn validate_ref_node(&self, ref_node: &RefNode, n_nodes: usize) -> Result<(), String> {
        _validate_ref_node(&ParseDecisionNetDepsImpl, ref_node, n_nodes)
    }

    fn validate_decision_net(&self, nodes: &[DecisionNode], feat_ids: &[String]) -> Result<(), String> {
        _validate_decision_net(&ParseDecisionNetDepsImpl, nodes, feat_ids)
    }

    fn parse_decision_net(&self, fields: Option<Fields>, feat_ids: &[String]) -> Result<DecisionNet, String> {
        _parse_decision_net(&ParseDecisionNetDepsImpl, fields, feat_ids)
    }
}

struct ParseDecisionNetDepsImpl;
impl ParseDecisionNetDeps for ParseDecisionNetDepsImpl {}

fn _parse_branch_node<T>(deps: &T, fields: &Fields) -> Result<BranchNode, String> where T: ParseDecisionNetDeps {
    let threshold = deps.option_f64(fields, &["threshold", "thresh"])?;
    let feat_id = deps.option_string(fields, &["feat_id", "feature_id"])?;
    let true_idx = deps.option_usize(fields, &["true_idx", "true_index"])?;
    let false_idx = deps.option_usize(fields, &["false_idx", "false_index"])?;
    Ok(BranchNode { threshold, feat_id, true_idx, false_idx, value: false })
}

fn _parse_ref_node<T>(deps: &T, fields: &Fields) -> Result<RefNode, String> where T: ParseDecisionNetDeps {
    let ref_idx = deps.option_usize(fields, &["ref_idx", "ref_index", "reference_idx", "reference_index"])?;
    let true_idx = deps.option_usize(fields, &["true_idx", "true_index"])?;
    let false_idx = deps.option_usize(fields, &["false_idx", "false-idx", "false_index"])?;
    Ok(RefNode { ref_idx, true_idx, false_idx, value: false })
}

fn _parse_decision_node<T>(deps: &T, fields: &Fields) -> Result<DecisionNode, String> where T: ParseDecisionNetDeps {
    let node_type = deps.string(fields, &["type"], "")?;

    match node_type.as_str() {
        "branch" => {
            let node = deps.parse_branch_node(fields)?;
            Ok(DecisionNode::Branch(node))
        }
        "ref" => {
            let node = deps.parse_ref_node(fields)?;
            Ok(DecisionNode::Ref(node))
        }
        _ => Err(format!("invalid decision node type: {node_type}"))
    }
}

fn _validate_branch_node<T>(deps: &T, branch: &BranchNode, ids: &HashSet<String>, n_nodes: usize) -> Result<(), String> where T: ParseDecisionNetDeps {
    if let Some(feat_id) = branch.feat_id.as_ref() && !ids.contains(feat_id.as_str()) {
        return Err(format!("feat_id not found: {feat_id}"));
    }
    deps.validate_idx(branch.true_idx, n_nodes, "true_idx")?;
    deps.validate_idx(branch.false_idx, n_nodes, "false_idx")?;
    Ok(())
}

fn _validate_ref_node<T>(deps: &T, ref_node: &RefNode, n_nodes: usize) -> Result<(), String> where T: ParseDecisionNetDeps {
    deps.validate_idx(ref_node.ref_idx, n_nodes, "ref_idx")?;
    deps.validate_idx(ref_node.true_idx, n_nodes, "true_idx")?;
    deps.validate_idx(ref_node.false_idx, n_nodes, "false_idx")?;
    Ok(())
}

fn _validate_decision_net<T>(deps: &T, nodes: &[DecisionNode], feat_ids: &[String]) -> Result<(), String> where T: ParseDecisionNetDeps {
    let ids = deps.feat_id_set(feat_ids);
    let n_nodes = nodes.len();
    for node in nodes {
        match node {
            DecisionNode::Branch(branch) => deps.validate_branch_node(branch, &ids, n_nodes)?,
            DecisionNode::Ref(ref_node) => deps.validate_ref_node(ref_node, n_nodes)?
        }
    }
    Ok(())
}

fn _parse_decision_net<T>(deps: &T, fields: Option<Fields>, feat_ids: &[String]) -> Result<DecisionNet, String> where T: ParseDecisionNetDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let default_value = deps.bool(&fields, &["default_value", "default-value", "default"], false)?;
    let max_trail_len = deps.usize(&fields, &["max_trail_len", "max-trail-len", "max_trail_length", "max-trail-length"], 8)?;
    let node_fields = deps.child_fields(&fields, &["nodes", "decision_nodes"])?;
    let indexed = deps.indexed_nodes_fields(node_fields)?;
    let mut nodes = Vec::new();
    for fields in &indexed {
        let node = deps.parse_decision_node(fields)?;
        nodes.push(node);
    }

    if max_trail_len == 0 {
        return Err("max_trail_len must be > 0".to_string());
    }
    if max_trail_len > MAX_TRAIL_LEN {
        return Err(format!("max_trail_len must be <= {MAX_TRAIL_LEN}"));
    }

    deps.validate_decision_net(&nodes, feat_ids)?;
    let net = DecisionNet { nodes, max_trail_len, default_value, idx_trail: Vec::new() };
    Ok(net)
}

pub fn parse_decision_net(fields: Option<Fields>, feat_ids: &[String]) -> Result<DecisionNet, String> {
    ParseDecisionNetDepsImpl.parse_decision_net(fields, feat_ids)
}

#[cfg_attr(test, automock)]
trait ParseDecisionPenaltiesDeps {
    fn f64<'a>(&self, fields: &Fields, keys: &[&'a str], default: f64) -> Result<f64, String> {
        fields.f64(keys, default)
    }

    fn expect_non_neg(&self, value: f64, field: &str) -> Result<(), String> {
        expect_non_neg(value, field)
    }
}

struct ParseDecisionPenaltiesDepsImpl;
impl ParseDecisionPenaltiesDeps for ParseDecisionPenaltiesDepsImpl {}

fn _parse_decision_penalties<T>(deps: &T, fields: Option<Fields>) -> Result<DecisionPenalties, String> where T: ParseDecisionPenaltiesDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let node = deps.f64(&fields, &["node", "node_penalty", "node-penalty"], 0.0)?;
    let branch = deps.f64(&fields, &["branch", "branch_penalty", "branch-penalty"], 0.0)?;
    let ref_ = deps.f64(&fields, &["ref", "ref_penalty", "ref-penalty", "reference", "reference_penalty", "reference-penalty"], 0.0)?;
    let leaf = deps.f64(&fields, &["leaf"], 0.0)?;
    let non_leaf = deps.f64(&fields, &["non_leaf"], 0.0)?;
    let used_feat = deps.f64(&fields, &["used_feat"], 0.0)?;
    let unused_feat = deps.f64(&fields, &["unused_feat"], 0.0)?;

    deps.expect_non_neg(node, "node")?;
    deps.expect_non_neg(branch, "branch")?;
    deps.expect_non_neg(ref_, "ref")?;
    deps.expect_non_neg(leaf, "leaf")?;
    deps.expect_non_neg(non_leaf, "non_leaf")?;
    deps.expect_non_neg(used_feat, "used_feat")?;
    deps.expect_non_neg(unused_feat, "unused_feat")?;

    let penalties = DecisionPenalties {
        node, branch, ref_, leaf, non_leaf, used_feat, unused_feat
    };
    Ok(penalties)
}

pub fn parse_decision_penalties(fields: Option<Fields>) -> Result<DecisionPenalties, String> {
    _parse_decision_penalties(&ParseDecisionPenaltiesDepsImpl, fields)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parse::parse::tests::gen_fields;
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize, gen_usize_between, gen_vec};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

    #[hegel::composite]
    fn gen_branch_node(tc: TestCase, feat_ids: Option<&[String]>) -> BranchNode {
        let threshold = if tc.draw(booleans()) { Some(tc.draw(gen_f64())) } else { None };

        let feat_id = if tc.draw(booleans()) {
            match feat_ids {
                Some(ids) => Some(tc.draw(sampled_from(ids))),
                None => {
                    let n_feats = tc.draw(gen_usize_between(1, 10));
                    let ids = tc.draw(gen_vec(gen_text(), n_feats));
                    Some(tc.draw(sampled_from(&ids)))
                }
            }
        } else { None };

        let true_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
        let false_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
        BranchNode { threshold, feat_id, true_idx, false_idx, value: tc.draw(booleans()) }
    }

    #[hegel::composite]
    fn gen_ref_node(tc: TestCase) -> RefNode {
        let ref_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
        let true_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
        let false_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
        RefNode { ref_idx, true_idx, false_idx, value: tc.draw(booleans()) }
    }

    mod parse_branch_node_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { Threshold, FeatId, TrueIdx, FalseIdx }

        #[derive(Debug)]
        struct TestContext {
            expected_node: BranchNode,
            result: Result<BranchNode, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(vec![
                InvalidCase::Threshold, InvalidCase::FeatId, InvalidCase::TrueIdx, InvalidCase::FalseIdx
            ]));
            let invalid_threshold = draw_invalid && invalid_case == InvalidCase::Threshold;
            let invalid_feat = draw_invalid && invalid_case == InvalidCase::FeatId;
            let invalid_true = draw_invalid && invalid_case == InvalidCase::TrueIdx;
            let invalid_false = draw_invalid && invalid_case == InvalidCase::FalseIdx;

            let node = tc.draw(gen_branch_node(None));
            let expected_node = BranchNode {
                threshold: node.threshold,
                feat_id: node.feat_id.clone(),
                true_idx: node.true_idx,
                false_idx: node.false_idx,
                value: false
            };

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseDecisionNetDeps::new();

            mock_deps.expect_option_f64()
                .times(1)
                .withf(|_, keys| *keys == ["threshold", "thresh"])
                .return_const(if invalid_threshold { Err(String::new()) } else { Ok(node.threshold) });
            
            mock_deps.expect_option_string()
                .times(usize::from(!invalid_threshold))
                .withf(|_, keys| *keys == ["feat_id", "feature_id"])
                .return_const(if invalid_feat { Err(String::new()) } else { Ok(node.feat_id) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_threshold && !invalid_feat))
                .withf(|_, keys| *keys == ["true_idx", "true_index"])
                .return_const(if invalid_true { Err(String::new()) } else { Ok(node.true_idx) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_threshold && !invalid_feat && !invalid_true))
                .withf(|_, keys| *keys == ["false_idx", "false_index"])
                .return_const(if invalid_false { Err(String::new()) } else { Ok(node.false_idx) });

            let result = _parse_branch_node(&mock_deps, &fields);
            TestContext { expected_node, result }
        }

        #[hegel::test]
        fn test_parse_branch_node(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_node));
        }

        #[hegel::test]
        fn test_parse_branch_node_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}