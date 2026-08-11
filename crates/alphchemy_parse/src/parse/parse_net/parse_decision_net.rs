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
    let false_idx = deps.option_usize(fields, &["false_idx", "false_index"])?;
    Ok(RefNode { ref_idx, true_idx, false_idx, value: false })
}

fn _parse_decision_node<T>(deps: &T, fields: &Fields) -> Result<DecisionNode, String> where T: ParseDecisionNetDeps {
    let node_type = deps.string(fields, &["type"], "branch")?;

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

    let default_value = deps.bool(&fields, &["default_value", "default"], false)?;
    let max_trail_len = deps.usize(&fields, &["max_trail_len", "max_trail_length"], 10)?;
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

    let node = deps.f64(&fields, &["node", "node_penalty"], 0.0)?;
    let branch = deps.f64(&fields, &["branch", "branch_penalty"], 0.0)?;
    let ref_ = deps.f64(&fields, &["ref", "ref_penalty", "reference", "reference_penalty"], 0.0)?;
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
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::{TestCase, generators::{booleans, sampled_from}};
    use std::cell::Cell;

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

            let mut expected_node = tc.draw(gen_branch_node(None));
            expected_node.value = false;

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseDecisionNetDeps::new();

            mock_deps.expect_option_f64()
                .times(1)
                .withf(|_, keys| *keys == ["threshold", "thresh"])
                .return_const(if invalid_threshold { Err(String::new()) } else { Ok(expected_node.threshold.clone()) });
            
            mock_deps.expect_option_string()
                .times(usize::from(!invalid_threshold))
                .withf(|_, keys| *keys == ["feat_id", "feature_id"])
                .return_const(if invalid_feat { Err(String::new()) } else { Ok(expected_node.feat_id.clone()) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_threshold && !invalid_feat))
                .withf(|_, keys| *keys == ["true_idx", "true_index"])
                .return_const(if invalid_true { Err(String::new()) } else { Ok(expected_node.true_idx.clone()) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_threshold && !invalid_feat && !invalid_true))
                .withf(|_, keys| *keys == ["false_idx", "false_index"])
                .return_const(if draw_invalid && invalid_case == InvalidCase::FalseIdx { Err(String::new()) } else { Ok(expected_node.false_idx.clone()) });

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

    mod parse_ref_node_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { RefIdx, TrueIdx, FalseIdx }

        #[derive(Debug)]
        struct TestContext {
            expected_node: RefNode,
            result: Result<RefNode, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(vec![InvalidCase::RefIdx, InvalidCase::TrueIdx, InvalidCase::FalseIdx]));
            let invalid_ref = draw_invalid && invalid_case == InvalidCase::RefIdx;
            let invalid_true = draw_invalid && invalid_case == InvalidCase::TrueIdx;

            let mut expected_node = tc.draw(gen_ref_node());
            expected_node.value = false;

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseDecisionNetDeps::new();

            mock_deps.expect_option_usize()
                .times(1)
                .withf(|_, keys| *keys == ["ref_idx", "ref_index", "reference_idx", "reference_index"])
                .return_const(if invalid_ref { Err(String::new()) } else { Ok(expected_node.ref_idx.clone()) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_ref))
                .withf(|_, keys| *keys == ["true_idx", "true_index"])
                .return_const(if invalid_true { Err(String::new()) } else { Ok(expected_node.true_idx.clone()) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_ref && !invalid_true))
                .withf(|_, keys| *keys == ["false_idx", "false_index"])
                .return_const(if draw_invalid && invalid_case == InvalidCase::FalseIdx { Err(String::new()) } else { Ok(expected_node.false_idx.clone()) });

            let result = _parse_ref_node(&mock_deps, &fields);
            TestContext { expected_node, result }
        }

        #[hegel::test]
        fn test_parse_ref_node(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_node));
        }

        #[hegel::test]
        fn test_parse_ref_node_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_decision_node_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum DecisionNodeCase { Branch, Ref, Invalid }

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { TypeString, Branch, Ref, Type }

        #[derive(Debug)]
        struct TestContext {
            expected_branch: DecisionNode,
            expected_ref: DecisionNode,
            result: Result<DecisionNode, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: DecisionNodeCase) -> TestContext {
            let invalid_case = tc.draw(sampled_from(vec![InvalidCase::TypeString, InvalidCase::Branch, InvalidCase::Ref, InvalidCase::Type]));
            let is_invalid = case == DecisionNodeCase::Invalid;
            let invalid_type_string = is_invalid && invalid_case == InvalidCase::TypeString;
            let invalid_branch = is_invalid && invalid_case == InvalidCase::Branch;
            let invalid_ref = is_invalid && invalid_case == InvalidCase::Ref;
            let invalid_type = is_invalid && invalid_case == InvalidCase::Type;

            let is_branch = case == DecisionNodeCase::Branch || invalid_branch;
            let is_ref = case == DecisionNodeCase::Ref || invalid_ref;

            let node_type = if is_branch {
                "branch".to_string()
            } else if is_ref {
                "ref".to_string()
            } else {
                let text = tc.draw(gen_text());
                if invalid_type {
                    let is_valid_type = text == "branch" || text == "ref";
                    tc.assume(!is_valid_type || !invalid_type);
                }
                text
            };

            let branch_node = tc.draw(gen_branch_node(None));
            let ref_node = tc.draw(gen_ref_node());

            let expected_branch = DecisionNode::Branch(branch_node.clone());
            let expected_ref = DecisionNode::Ref(ref_node.clone());

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseDecisionNetDeps::new();

            mock_deps.expect_string()
                .times(1)
                .withf(|_, keys, default| *keys == ["type"] && default == "branch")
                .return_const(if invalid_type_string { Err(String::new()) } else { 
                    Ok(node_type) 
                });

            mock_deps.expect_parse_branch_node()
                .times(usize::from(is_branch))
                .return_const(if invalid_branch { Err(String::new()) } else { Ok(branch_node) });

            mock_deps.expect_parse_ref_node()
                .times(usize::from(is_ref))
                .return_const(if invalid_ref { Err(String::new()) } else { Ok(ref_node) });

            let result = _parse_decision_node(&mock_deps, &fields);
            TestContext { expected_branch, expected_ref, result }
        }

        #[hegel::test]
        fn test_parse_decision_node_branch(tc: TestCase) {
            let ctx = tc.draw(gen_context(DecisionNodeCase::Branch));
            assert_eq!(ctx.result, Ok(ctx.expected_branch));
        }

        #[hegel::test]
        fn test_parse_decision_node_ref(tc: TestCase) {
            let ctx = tc.draw(gen_context(DecisionNodeCase::Ref));
            assert_eq!(ctx.result, Ok(ctx.expected_ref));
        }

        #[hegel::test]
        fn test_parse_decision_node_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(DecisionNodeCase::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod validate_branch_node_tests {

        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { FeatId, TrueIdx, FalseIdx }

        #[derive(Debug)]
        struct TestContext {
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[InvalidCase::FeatId, InvalidCase::TrueIdx, InvalidCase::FalseIdx]));

            let n_feats = tc.draw(gen_usize_between(1, 10));
            let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));
            let mut branch_node = tc.draw(gen_branch_node(Some(&feat_ids)));
            if draw_invalid && invalid_case == InvalidCase::FeatId {
                let missing_id = tc.draw(gen_text());
                tc.assume(!feat_ids.contains(&missing_id));
                branch_node.feat_id = Some(missing_id);
            }

            let n_nodes = tc.draw(gen_usize_between(1, 10));
            let ids = feat_ids.iter().cloned().collect::<HashSet<_>>();

            let mut mock_deps = MockParseDecisionNetDeps::new();
            mock_deps.expect_validate_idx()
                .times(usize::from(!draw_invalid || [InvalidCase::TrueIdx, InvalidCase::FalseIdx].contains(&invalid_case)))
                .withf(|_, _, field| field == "true_idx")
                .return_const(if draw_invalid && invalid_case == InvalidCase::TrueIdx { Err(String::new()) } else { Ok(()) });
            mock_deps.expect_validate_idx()
                .times(usize::from(!draw_invalid || invalid_case == InvalidCase::FalseIdx))
                .withf(|_, _, field| field == "false_idx")
                .return_const(if  draw_invalid && invalid_case == InvalidCase::FalseIdx { Err(String::new()) } else { Ok(()) });

            let result = _validate_branch_node(&mock_deps, &branch_node, &ids, n_nodes);
            TestContext { result }
        }

        #[hegel::test]
        fn test_validate_branch_node(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert!(ctx.result.is_ok());
        }

        #[hegel::test]
        fn test_validate_branch_node_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod validate_ref_node_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { RefIdx, TrueIdx, FalseIdx }

        #[derive(Debug)]
        struct TestContext {
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[
                InvalidCase::RefIdx, InvalidCase::TrueIdx, InvalidCase::FalseIdx
            ]));
            let ref_node = tc.draw(gen_ref_node());
            let n_nodes = tc.draw(gen_usize_between(1, 10));

            let mut mock_deps = MockParseDecisionNetDeps::new();
            mock_deps.expect_validate_idx()
                .times(1)
                .withf(|_, _, field| field == "ref_idx")
                .return_const(if draw_invalid && invalid_case == InvalidCase::RefIdx {
                    Err(String::new())
                } else { Ok(()) });
            mock_deps.expect_validate_idx()
                .times(usize::from(!draw_invalid || [InvalidCase::TrueIdx, InvalidCase::FalseIdx].contains(&invalid_case)))
                .withf(|_, _, field| field == "true_idx")
                .return_const(if draw_invalid && invalid_case == InvalidCase::TrueIdx {
                    Err(String::new())
                } else { Ok(()) });
            mock_deps.expect_validate_idx()
                .times(usize::from(!draw_invalid || invalid_case == InvalidCase::FalseIdx))
                .withf(|_, _, field| field == "false_idx")
                .return_const(if draw_invalid && invalid_case == InvalidCase::FalseIdx {
                    Err(String::new())
                } else { Ok(()) });

            let result = _validate_ref_node(&mock_deps, &ref_node, n_nodes);
            TestContext { result }
        }

        #[hegel::test]
        fn test_validate_ref_node(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(()));
        }

        #[hegel::test]
        fn test_validate_ref_node_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod validate_decision_net_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_branch = draw_invalid && tc.draw(booleans());

            let n_feats = tc.draw(gen_usize_between(1, 10));
            let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));

            let n_nodes = tc.draw(gen_usize_between(1, 10));
            let invalid_idx = tc.draw(gen_usize_with_max(n_nodes - 1));

            let mut nodes = Vec::new();
            let mut n_branch_ok = 0;
            let mut n_ref_ok = 0;
            let mut still_validating = true;
            for i in 0..n_nodes {
                if draw_invalid && i == invalid_idx {
                    if invalid_branch {
                        nodes.push(DecisionNode::Branch(tc.draw(gen_branch_node(Some(&feat_ids)))));
                    } else {
                        nodes.push(DecisionNode::Ref(tc.draw(gen_ref_node())));
                    }
                    still_validating = false;
                } else if tc.draw(booleans()) {
                    nodes.push(DecisionNode::Branch(tc.draw(gen_branch_node(Some(&feat_ids)))));
                    if still_validating {
                        n_branch_ok += 1;
                    }
                } else {
                    nodes.push(DecisionNode::Ref(tc.draw(gen_ref_node())));
                    if still_validating {
                        n_ref_ok += 1;
                    }
                }
            }

            let mut mock_deps = MockParseDecisionNetDeps::new();

            mock_deps.expect_feat_id_set()
                .times(1)
                .withf({
                    let expected_feat_ids = feat_ids.clone();
                    move |ids| *ids == expected_feat_ids
                })
                .return_const(feat_ids.iter().cloned().collect::<HashSet<_>>());

            let branch_oks = Cell::new(n_branch_ok);
            mock_deps.expect_validate_branch_node()
                .times(n_branch_ok + usize::from(invalid_branch))
                .returning(move |_, _, _| {
                    if branch_oks.get() > 0 {
                        branch_oks.set(branch_oks.get() - 1);
                        Ok(())
                    } else { Err(String::new()) }
                });

            let ref_oks = Cell::new(n_ref_ok);
            mock_deps.expect_validate_ref_node()
                .times(n_ref_ok + usize::from(draw_invalid && !invalid_branch))
                .returning(move |_, _| {
                    if ref_oks.get() > 0 {
                        ref_oks.set(ref_oks.get() - 1);
                        Ok(())
                    } else { Err(String::new()) }
                });

            let result = _validate_decision_net(&mock_deps, &nodes, &feat_ids);
            TestContext { result }
        }

        #[hegel::test]
        fn test_validate_decision_net(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert!(ctx.result.is_ok());
        }

        #[hegel::test]
        fn test_validate_decision_net_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_decision_net_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase {
            Default, MaxTrailLen, MaxTrailZero, MaxTrailTooLarge,
            NodeFields, Indexed, ParseNode, Validate
        }

        #[derive(Debug)]
        struct TestContext {
            expected_net: DecisionNet,
            result: Result<DecisionNet, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[InvalidCase::Default, InvalidCase::MaxTrailLen, InvalidCase::MaxTrailZero, InvalidCase::MaxTrailTooLarge,InvalidCase::NodeFields, InvalidCase::Indexed, InvalidCase::ParseNode, InvalidCase::Validate]));

            let fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };
            let default_value = tc.draw(booleans());
            let node_fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };

            let max_trail_len = if draw_invalid && invalid_case == InvalidCase::MaxTrailZero {
                0
            } else if draw_invalid && invalid_case == InvalidCase::MaxTrailTooLarge {
                tc.draw(gen_usize_between(MAX_TRAIL_LEN + 1, MAX_TRAIL_LEN + 10))
            } else {
                tc.draw(gen_usize_between(1, MAX_TRAIL_LEN))
            };

            let n_feats = tc.draw(gen_usize_between(1, 10));
            let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));

            let n_nodes = if draw_invalid && invalid_case == InvalidCase::ParseNode {
                tc.draw(gen_usize_between(1, 10))
            } else {
                tc.draw(gen_usize_with_max(10))
            };
            let invalid_idx = if draw_invalid && invalid_case == InvalidCase::ParseNode {
                tc.draw(gen_usize_with_max(n_nodes - 1))
            } else { 0 };

            let mut indexed = Vec::new();
            let mut nodes = Vec::new();
            for _ in 0..n_nodes {
                indexed.push(tc.draw(gen_fields()));
                if tc.draw(booleans()) {
                    nodes.push(DecisionNode::Branch(tc.draw(gen_branch_node(Some(&feat_ids)))));
                } else {
                    nodes.push(DecisionNode::Ref(tc.draw(gen_ref_node())));
                }
            }

            let expected_net = DecisionNet {
                nodes: nodes.clone(),
                max_trail_len,
                default_value,
                idx_trail: Vec::new()
            };
            let mut mock_deps = MockParseDecisionNetDeps::new();

            mock_deps.expect_bool()
                .times(1)
                .withf(|_, keys, default| *keys == ["default_value", "default"] && !default)
                .return_const(if draw_invalid && invalid_case == InvalidCase::Default {
                    Err(String::new())
                } else { Ok(default_value) });

            mock_deps.expect_usize()
                .times(usize::from(!draw_invalid || invalid_case != InvalidCase::Default))
                .withf(|_, keys, default| {
                    *keys == ["max_trail_len", "max_trail_length"] && *default == 10
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::MaxTrailLen {
                    Err(String::new())
                } else { Ok(max_trail_len) });

            mock_deps.expect_child_fields()
                .times(usize::from(!draw_invalid || ![InvalidCase::Default, InvalidCase::MaxTrailLen].contains(&invalid_case)))
                .withf(|_, keys| *keys == ["nodes", "decision_nodes"])
                .return_const(if draw_invalid && invalid_case == InvalidCase::NodeFields {
                    Err(String::new())
                } else { Ok(node_fields) });

            mock_deps.expect_indexed_nodes_fields()
                .times(usize::from(!draw_invalid || ![
                    InvalidCase::Default, InvalidCase::MaxTrailLen, InvalidCase::NodeFields
                ].contains(&invalid_case)))
                .return_const(if draw_invalid && invalid_case == InvalidCase::Indexed {
                    Err(String::new())
                } else { Ok(indexed) });

            let parse_idx = Cell::new(0);
            let nodes_for_parse = nodes.clone();
            mock_deps.expect_parse_decision_node()
                .times(if draw_invalid && invalid_case == InvalidCase::ParseNode {
                    invalid_idx + 1
                } else if !draw_invalid || ![InvalidCase::Default, InvalidCase::MaxTrailLen, InvalidCase::NodeFields, InvalidCase::Indexed].contains(&invalid_case) {
                    n_nodes
                } else { 0 })
                .returning(move |_| {
                    let idx = parse_idx.get();

                    if draw_invalid && invalid_case == InvalidCase::ParseNode && idx == invalid_idx {
                        return Err(String::new())
                    }

                    parse_idx.set(idx + 1);
                    Ok(nodes_for_parse[idx].clone())
                });

            mock_deps.expect_validate_decision_net()
                .times(usize::from(!draw_invalid || invalid_case == InvalidCase::Validate))
                .withf({
                    let expected_nodes = nodes.clone();
                    let expected_feat_ids = feat_ids.clone();
                    move |actual_nodes, actual_feat_ids| {
                        if *actual_nodes != expected_nodes { return false }
                        *actual_feat_ids == expected_feat_ids
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Validate {
                    Err(String::new())
                } else { Ok(()) });

            let result = _parse_decision_net(&mock_deps, fields, &feat_ids);
            TestContext { expected_net, result }
        }

        #[hegel::test]
        fn test_parse_decision_net(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_net));
        }

        #[hegel::test]
        fn test_parse_decision_net_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_decision_penalties_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_penalties: DecisionPenalties,
            result: Result<DecisionPenalties, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_f64 = draw_invalid && tc.draw(booleans());
            let invalid_non_neg = draw_invalid && !invalid_f64;
            let fail_idx = tc.draw(gen_usize_with_max(6));

            let expected_penalties = DecisionPenalties {
                node: tc.draw(gen_f64()),
                branch: tc.draw(gen_f64()),
                ref_: tc.draw(gen_f64()),
                leaf: tc.draw(gen_f64()),
                non_leaf: tc.draw(gen_f64()),
                used_feat: tc.draw(gen_f64()),
                unused_feat: tc.draw(gen_f64())
            };
            let fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };
            let values = [expected_penalties.node, expected_penalties.branch, expected_penalties.ref_, expected_penalties.leaf, expected_penalties.non_leaf, expected_penalties.used_feat, expected_penalties.unused_feat];
            let keys: [&[&str]; 7] = [
                &["node", "node_penalty"],
                &["branch", "branch_penalty"],
                &["ref", "ref_penalty", "reference", "reference_penalty"],
                &["leaf"],
                &["non_leaf"],
                &["used_feat"],
                &["unused_feat"]
            ];
            let labels = ["node", "branch", "ref", "leaf", "non_leaf", "used_feat", "unused_feat"];

            let mut mock_deps = MockParseDecisionPenaltiesDeps::new();
            let valid_f64 = !invalid_f64;

            for i in 0..7 {
                mock_deps.expect_f64()
                    .times(usize::from(valid_f64 || i <= fail_idx))
                    .withf(move |_, actual_keys, default| *actual_keys == *keys[i] && *default == 0.0)
                    .return_const(if invalid_f64 && i == fail_idx { Err(String::new()) } else { Ok(values[i]) });
            }

            for i in 0..7 {
                let valid_upto = !invalid_non_neg || i <= fail_idx;
                mock_deps.expect_expect_non_neg()
                    .times(usize::from(valid_f64 && valid_upto))
                    .withf(move |actual_value, field| *actual_value == values[i] && field == labels[i])
                    .return_const(if invalid_non_neg && i == fail_idx { Err(String::new()) } else { Ok(()) });
            }

            let result = _parse_decision_penalties(&mock_deps, fields);
            TestContext { expected_penalties, result }
        }

        #[hegel::test]
        fn test_parse_decision_penalties(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_penalties));
        }

        #[hegel::test]
        fn test_parse_decision_penalties_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}