use std::collections::HashSet;

use alphchemy_engine::network::logic_net::{LogicNet, LogicNode, InputNode, GateNode, Gate, LogicPenalties};
use crate::utils::expect_non_neg;
use super::super::parse::Fields;

#[cfg(test)]
use mockall::automock;

#[cfg_attr(test, automock)]
trait ParseLogicNetDeps {
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

    fn child_fields<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Result<Option<Fields>, String> {
        fields.child_fields(keys)
    }

    fn parse_gate(&self, text: &str) -> Result<Gate, String> {
        match text {
            "and" | "And" | "AND" | "&&" | "&" => Ok(Gate::And),
            "or" | "Or" | "OR" | "||" | "|" => Ok(Gate::Or),
            "xor" | "Xor" | "XOR" | "^" => Ok(Gate::Xor),
            "nand" | "Nand" | "NAND" | "!&&" | "!&" => Ok(Gate::Nand),
            "nor" | "Nor" | "NOR" | "!|" | "!||" => Ok(Gate::Nor),
            "xnor" | "Xnor" | "XNOR" | "!^" => Ok(Gate::Xnor),
            _ => Err(format!("invalid gate: {text}"))
        }
    }

    fn parse_option_gate(&self, fields: &Fields) -> Result<Option<Gate>, String> {
        _parse_option_gate(&ParseLogicNetDepsImpl, fields)
    }

    fn parse_input_node(&self, fields: &Fields) -> Result<InputNode, String> {
        _parse_input_node(&ParseLogicNetDepsImpl, fields)
    }

    fn parse_gate_node(&self, fields: &Fields) -> Result<GateNode, String> {
        _parse_gate_node(&ParseLogicNetDepsImpl, fields)
    }

    fn parse_logic_node(&self, fields: &Fields) -> Result<LogicNode, String> {
        _parse_logic_node(&ParseLogicNetDepsImpl, fields)
    }

    fn feat_id_set(&self, feat_ids: &[String]) -> HashSet<String> {
        feat_ids.iter().cloned().collect()
    }

    fn validate_idx(&self, idx: Option<usize>, n_nodes: usize, field: &str) -> Result<(), String> {
        super::parse_net::validate_idx(idx, n_nodes, field)
    }

    fn validate_logic_net(&self, nodes: &[LogicNode], feat_ids: &[String]) -> Result<(), String> {
        _validate_logic_net(&ParseLogicNetDepsImpl, nodes, feat_ids)
    }

    fn indexed_nodes_fields(&self, fields: Option<Fields>) -> Result<Vec<Fields>, String> {
        super::parse_net::indexed_node_fields(fields)
    }

    fn parse_logic_net(&self, fields: Option<Fields>, feat_ids: &[String]) -> Result<LogicNet, String> {
        _parse_logic_net(&ParseLogicNetDepsImpl, fields, feat_ids)
    }
}

struct ParseLogicNetDepsImpl;
impl ParseLogicNetDeps for ParseLogicNetDepsImpl {}

fn _parse_option_gate<T>(deps: &T, fields: &Fields) -> Result<Option<Gate>, String> where T: ParseLogicNetDeps {
    match deps.option_string(fields, &["gate"])? {
        None => Ok(None),
        Some(text) => {
            let gate = deps.parse_gate(&text)?;
            Ok(Some(gate))
        }
    }
}

fn _parse_input_node<T>(deps: &T, fields: &Fields) -> Result<InputNode, String> where T: ParseLogicNetDeps {
    let threshold = deps.option_f64(fields, &["threshold"])?;
    let feat_id = deps.option_string(fields, &["feat_id", "feature_id"])?;
    let node = InputNode { threshold, feat_id, value: false };
    Ok(node)
}

fn _parse_gate_node<T>(deps: &T, fields: &Fields) -> Result<GateNode, String> where T: ParseLogicNetDeps {
    let gate = deps.parse_option_gate(fields)?;
    let in1_idx = deps.option_usize(fields, &["in1_idx", "in1", "input1"])?;
    let in2_idx = deps.option_usize(fields, &["in2_idx", "in2", "input2"])?;
    let node = GateNode { gate, in1_idx, in2_idx, value: false };
    Ok(node)
}

fn _parse_logic_node<T>(deps: &T, fields: &Fields) -> Result<LogicNode, String> where T: ParseLogicNetDeps {
    let node_type = deps.string(fields, &["type", "net_type", "network_type"], "input")?;

    match node_type.as_str() {
        "input" => {
            let node = deps.parse_input_node(fields)?;
            Ok(LogicNode::Input(node))
        }
        "gate" => {
            let node = deps.parse_gate_node(fields)?;
            Ok(LogicNode::Gate(node))
        }
        _ => Err(format!("invalid logic node type: {node_type}"))
    }
}

fn _validate_logic_net<T>(deps: &T, nodes: &[LogicNode], feat_ids: &[String]) -> Result<(), String> where T: ParseLogicNetDeps {
    let unique_ids = deps.feat_id_set(feat_ids);
    let n_nodes = nodes.len();
    for node in nodes {
        match node {
            LogicNode::Input(input) => {
                if let Some(feat_id) = input.feat_id.as_ref() && !unique_ids.contains(feat_id) {
                    return Err(format!("feat_id not found: {feat_id}"));
                }
            }
            LogicNode::Gate(gate) => {
                deps.validate_idx(gate.in1_idx, n_nodes, "in1_idx")?;
                deps.validate_idx(gate.in2_idx, n_nodes, "in2_idx")?;
            }
        }
    }
    Ok(())
}

fn _parse_logic_net<T>(deps: &T, fields: Option<Fields>, feat_ids: &[String]) -> Result<LogicNet, String> where T: ParseLogicNetDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let default_value = deps.bool(&fields, &["default_value", "default"], false)?;
    let node_fields = deps.child_fields(&fields, &["nodes", "logic_nodes"])?;
    let indexed = deps.indexed_nodes_fields(node_fields)?;
    let mut nodes = Vec::new();

    for fields in &indexed {
        let node = deps.parse_logic_node(fields)?;
        nodes.push(node);
    }

    deps.validate_logic_net(&nodes, feat_ids)?;
    Ok(LogicNet { nodes, default_value })
}

pub fn parse_gate(text: &str) -> Result<Gate, String> {
    ParseLogicNetDepsImpl.parse_gate(text)
}

pub fn parse_logic_net(fields: Option<Fields>, feat_ids: &[String]) -> Result<LogicNet, String> {
    ParseLogicNetDepsImpl.parse_logic_net(fields, feat_ids)
}

#[cfg_attr(test, automock)]
trait ParseLogicPenaltiesDeps {
    fn f64<'a>(&self, fields: &Fields, keys: &[&'a str], default: f64) -> Result<f64, String> {
        fields.f64(keys, default)
    }

    fn expect_non_neg(&self, value: f64, field: &str) -> Result<(), String> {
        expect_non_neg(value, field)
    }   
}

struct ParseLogicPenaltiesDepsImpl;
impl ParseLogicPenaltiesDeps for ParseLogicPenaltiesDepsImpl {}

fn _parse_logic_penalties<T>(deps: &T, fields: Option<Fields>) -> Result<LogicPenalties, String> where T: ParseLogicPenaltiesDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let node = deps.f64(&fields, &["node", "node_penalty"], 0.0)?;
    let input = deps.f64(&fields, &["input", "input_penalty"], 0.0)?;
    let gate = deps.f64(&fields, &["gate", "gate_penalty"], 0.0)?;
    let recurrence = deps.f64(&fields, &["recurrence", "recurrence_penalty", "rec", "rec_penalty"], 0.0)?;
    let feedforward = deps.f64(&fields, &["feedforward", "feedforward_penalty"], 0.0)?;
    let used_feat = deps.f64(&fields, &["used_feat", "used_feat_penalty", "used_feature", "used_feature_penalty"], 0.0)?;
    let unused_feat = deps.f64(&fields, &["unused_feat", "unused_feature"], 0.0)?;

    deps.expect_non_neg(node, "node penalty")?;
    deps.expect_non_neg(input, "input penalty")?;
    deps.expect_non_neg(gate, "gate penalty")?;
    deps.expect_non_neg(recurrence, "recurrence")?;
    deps.expect_non_neg(feedforward, "feedforward")?;
    deps.expect_non_neg(used_feat, "used feature")?;
    deps.expect_non_neg(unused_feat, "unused feature")?;

    Ok(LogicPenalties {
        node, input, gate, recurrence, feedforward, used_feat, unused_feat
    })
}

pub fn parse_logic_penalties(fields: Option<Fields>) -> Result<LogicPenalties, String> {
    _parse_logic_penalties(&ParseLogicPenaltiesDepsImpl, fields)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parse::parse::tests::gen_fields;
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

    #[hegel::composite]
    fn gen_input_node(tc: TestCase, feat_ids: Option<&[String]>) -> InputNode {
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

        InputNode { threshold, feat_id, value: tc.draw(booleans()) }
    }

    #[hegel::composite]
    fn gen_gate_node(tc: TestCase) -> GateNode {
        let gate = if tc.draw(booleans()) {
            Some(tc.draw(sampled_from(vec![
                Gate::And, Gate::Or, Gate::Xor, Gate::Nand, Gate::Nor, Gate::Xnor
            ])))
        } else { None };
        let in1_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
        let in2_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
        GateNode { gate, in1_idx, in2_idx, value: tc.draw(booleans()) }
    }

    mod test_parse_gate {
        use super::*;

        #[hegel::test]
        fn test_parse_gate_and(tc: TestCase) {
            let text = tc.draw(sampled_from(vec!["and", "And", "AND", "&&", "&"]));
            let result = ParseLogicNetDepsImpl.parse_gate(&text);
            assert_eq!(result, Ok(Gate::And));
        }

        #[hegel::test]
        fn test_parse_gate_or(tc: TestCase) {
            let text = tc.draw(sampled_from(vec!["or", "Or", "OR", "||", "|"]));
            let result = ParseLogicNetDepsImpl.parse_gate(&text);
            assert_eq!(result, Ok(Gate::Or));
        }

        #[hegel::test]
        fn test_parse_gate_xor(tc: TestCase) {
            let text = tc.draw(sampled_from(vec!["xor", "Xor", "XOR", "^"]));
            let result = ParseLogicNetDepsImpl.parse_gate(&text);
            assert_eq!(result, Ok(Gate::Xor));
        }

        #[hegel::test]
        fn test_parse_gate_nand(tc: TestCase) {
            let text = tc.draw(sampled_from(vec!["nand", "Nand", "NAND", "!&&", "!&"]));
            let result = ParseLogicNetDepsImpl.parse_gate(&text);
            assert_eq!(result, Ok(Gate::Nand));
        }

        #[hegel::test]
        fn test_parse_gate_nor(tc: TestCase) {
            let text = tc.draw(sampled_from(vec!["nor", "Nor", "NOR", "!|", "!||"]));
            let result = ParseLogicNetDepsImpl.parse_gate(&text);
            assert_eq!(result, Ok(Gate::Nor));
        }

        #[hegel::test]
        fn test_parse_gate_xnor(tc: TestCase) {
            let text = tc.draw(sampled_from(vec!["xnor", "Xnor", "XNOR", "!^"]));
            let result = ParseLogicNetDepsImpl.parse_gate(&text);
            assert_eq!(result, Ok(Gate::Xnor));
        }

        #[hegel::test]
        fn test_parse_gate_invalid(tc: TestCase) {
            let text = tc.draw(gen_text());
            let is_valid = matches!(text.as_str(),
                "and" | "And" | "AND" | "&&" | "&" |
                "or" | "Or" | "OR" | "||" | "|" |
                "xor" | "Xor" | "XOR" | "^" |
                "nand" | "Nand" | "NAND" | "!&&" | "!&" |
                "nor" | "Nor" | "NOR" | "!|" | "!||" |
                "xnor" | "Xnor" | "XNOR" | "!^"
            );
            tc.assume(!is_valid);
            let result = ParseLogicNetDepsImpl.parse_gate(&text);
            assert!(result.is_err());
        }
    }

    mod parse_input_node_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_node: InputNode,
            result: Result<InputNode, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_threshold = draw_invalid && tc.draw(booleans());

            let node = tc.draw(gen_input_node(None));
            let expected_node = InputNode {
                threshold: node.threshold.clone(),
                feat_id: node.feat_id.clone(),
                value: false
            };

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseLogicNetDeps::new();

            mock_deps.expect_option_f64()
                .times(1)
                .withf(|_, keys| *keys == ["threshold"])
                .return_const(if invalid_threshold { Err(String::new()) } else { Ok(node.threshold) });

            mock_deps.expect_option_string()
                .times(usize::from(!invalid_threshold))
                .withf(|_, keys| *keys == ["feat_id", "feature_id"])
                .return_const(if draw_invalid && !invalid_threshold { Err(String::new()) } else { Ok(node.feat_id) });

            let result = _parse_input_node(&mock_deps, &fields);
            TestContext { expected_node, result }
        }

        #[hegel::test]
        fn test_parse_input_node(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_node));
        }

        #[hegel::test]
        fn test_parse_input_node_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_gate_node_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { Gate, In1Idx, In2Idx }

        #[derive(Debug)]
        struct TestContext {
            expected_node: GateNode,
            result: Result<GateNode, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(vec![
                InvalidCase::Gate, InvalidCase::In1Idx, InvalidCase::In2Idx
            ]));
            let invalid_gate = draw_invalid && invalid_case == InvalidCase::Gate;
            let invalid_in1 = draw_invalid && invalid_case == InvalidCase::In1Idx;
            let invalid_in2 = draw_invalid && invalid_case == InvalidCase::In2Idx;

            let node = tc.draw(gen_gate_node());
            let expected_node = GateNode {
                gate: node.gate,
                in1_idx: node.in1_idx,
                in2_idx: node.in2_idx,
                value: false
            };

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseLogicNetDeps::new();

            mock_deps.expect_parse_option_gate()
                .times(1)
                .return_const(if invalid_gate { Err(String::new()) } else { Ok(node.gate) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_gate))
                .withf(|_, keys| *keys == ["in1_idx", "in1", "input1"])
                .return_const(if invalid_in1 { Err(String::new()) } else { Ok(node.in1_idx) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_gate && !invalid_in1))
                .withf(|_, keys| *keys == ["in2_idx", "in2", "input2"])
                .return_const(if invalid_in2 { Err(String::new()) } else { Ok(node.in2_idx) });

            let result = _parse_gate_node(&mock_deps, &fields);
            TestContext { expected_node, result }
        }

        #[hegel::test]
        fn test_parse_gate_node(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_node));
        }

        #[hegel::test]
        fn test_parse_gate_node_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_logic_node_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum LogicNodeCase { Input, Gate, Invalid }

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { TypeString, Input, Gate, Type }

        #[derive(Debug)]
        struct TestContext {
            expected_input: LogicNode,
            expected_gate: LogicNode,
            result: Result<LogicNode, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: LogicNodeCase) -> TestContext {
            let invalid_case = tc.draw(sampled_from(vec![InvalidCase::TypeString, InvalidCase::Input, InvalidCase::Gate, InvalidCase::Type]));
            let is_invalid = case == LogicNodeCase::Invalid;
            let invalid_type_string = is_invalid && invalid_case == InvalidCase::TypeString;
            let invalid_input = is_invalid && invalid_case == InvalidCase::Input;
            let invalid_gate = is_invalid && invalid_case == InvalidCase::Gate;
            let invalid_type = is_invalid && invalid_case == InvalidCase::Type;

            let is_input = case == LogicNodeCase::Input || invalid_input;
            let is_gate = case == LogicNodeCase::Gate || invalid_gate;

            let node_type = if is_input {
                "input".to_string()
            } else if is_gate {
                "gate".to_string()
            } else {
                let text = tc.draw(gen_text());
                let is_valid_type = text == "input" || text == "gate";
                tc.assume(!is_valid_type || !invalid_type);
                text
            };

            let input_node = tc.draw(gen_input_node(None));
            let gate_node = tc.draw(gen_gate_node());

            let expected_input = LogicNode::Input(input_node.clone());
            let expected_gate = LogicNode::Gate(gate_node.clone());

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseLogicNetDeps::new();

            mock_deps.expect_string()
                .times(1)
                .withf(|_, keys, default| *keys == ["type", "net_type", "network_type"] && default == "input")
                .return_const(if invalid_type_string { Err(String::new()) } else { Ok(node_type) });

            mock_deps.expect_parse_input_node()
                .times(usize::from(is_input && !invalid_type_string))
                .return_const(if invalid_input { Err(String::new()) } else { Ok(input_node) });

            mock_deps.expect_parse_gate_node()
                .times(usize::from(is_gate && !invalid_type_string))
                .return_const(if invalid_gate { Err(String::new()) } else { Ok(gate_node) });

            let result = _parse_logic_node(&mock_deps, &fields);
            TestContext { expected_input, expected_gate, result }
        }

        #[hegel::test]
        fn test_parse_logic_node_input(tc: TestCase) {
            let ctx = tc.draw(gen_context(LogicNodeCase::Input));
            assert_eq!(ctx.result, Ok(ctx.expected_input));
        }

        #[hegel::test]
        fn test_parse_logic_node_gate(tc: TestCase) {
            let ctx = tc.draw(gen_context(LogicNodeCase::Gate));
            assert_eq!(ctx.result, Ok(ctx.expected_gate));
        }

        #[hegel::test]
        fn test_parse_logic_node_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(LogicNodeCase::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod validate_logic_net_tests {
        use super::*;
        use std::cell::Cell;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { FeatId, In1Idx, In2Idx }

        #[derive(Debug)]
        struct TestContext {
            result: Result<(), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(vec![
                InvalidCase::FeatId, InvalidCase::In1Idx, InvalidCase::In2Idx
            ]));
            let invalid_in2 = draw_invalid && invalid_case == InvalidCase::In2Idx;

            let n_feats = tc.draw(gen_usize_between(1, 10));
            let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));

            let n_nodes = tc.draw(gen_usize_between(1, 10));
            let invalid_idx = tc.draw(gen_usize_with_max(n_nodes - 1));

            let mut nodes = Vec::new();
            let mut n_in1_ok = 0;
            let mut n_in2_ok = 0;
            let mut still_validating = true;
            for i in 0..n_nodes {
                if draw_invalid && i == invalid_idx {
                    match invalid_case {
                        InvalidCase::FeatId => {
                            let mut node = tc.draw(gen_input_node(Some(&feat_ids)));
                            let missing_id = tc.draw(gen_text());
                            tc.assume(!feat_ids.contains(&missing_id));
                            node.feat_id = Some(missing_id);

                            let input_node = LogicNode::Input(node);
                            nodes.push(input_node);
                        }
                        InvalidCase::In1Idx | InvalidCase::In2Idx => {
                            let gate_node = LogicNode::Gate(tc.draw(gen_gate_node()));
                            nodes.push(gate_node);
                            if invalid_in2 { n_in1_ok += 1 }
                        }
                    }
                    still_validating = false;
                } else if tc.draw(booleans()) {
                    nodes.push(LogicNode::Input(tc.draw(gen_input_node(Some(&feat_ids)))));
                } else {
                    nodes.push(LogicNode::Gate(tc.draw(gen_gate_node())));
                    if still_validating {
                        n_in1_ok += 1;
                        n_in2_ok += 1;
                    }
                }
            }

            let mut mock_deps = MockParseLogicNetDeps::new();

            mock_deps.expect_feat_id_set()
                .times(1)
                .withf({
                    let expected_feat_ids = feat_ids.clone();
                    move |ids| *ids == expected_feat_ids
                })
                .return_const(feat_ids.iter().cloned().collect::<HashSet<_>>());

            let in1_oks = Cell::new(n_in1_ok);
            mock_deps.expect_validate_idx()
                .times(n_in1_ok + usize::from(draw_invalid && invalid_case == InvalidCase::In1Idx))
                .withf(|_, _, field| field == "in1_idx")
                .returning(move |_, _, _| {
                    if in1_oks.get() > 0 {
                        in1_oks.set(in1_oks.get() - 1);
                        Ok(())
                    } else { Err(String::new()) }
                });

            let in2_oks = Cell::new(n_in2_ok);
            mock_deps.expect_validate_idx()
                .times(n_in2_ok + usize::from(invalid_in2))
                .withf(|_, _, field| field == "in2_idx")
                .returning(move |_, _, _| {
                    if in2_oks.get() > 0 {
                        in2_oks.set(in2_oks.get() - 1);
                        Ok(())
                    } else { Err(String::new()) }
                });

            let result = _validate_logic_net(&mock_deps, &nodes, &feat_ids);
            TestContext { result }
        }

        #[hegel::test]
        fn test_validate_logic_net(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(()));
        }

        #[hegel::test]
        fn test_validate_logic_net_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_logic_net_tests {
        use super::*;
        use std::cell::Cell;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { Default, NodeFields, Indexed, ParseNode, Validate }

        #[derive(Debug)]
        struct TestContext {
            expected_net: LogicNet,
            result: Result<LogicNet, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(vec![InvalidCase::Default, InvalidCase::NodeFields, InvalidCase::Indexed, InvalidCase::ParseNode, InvalidCase::Validate]));
            let invalid_default = draw_invalid && invalid_case == InvalidCase::Default;
            let invalid_fields = draw_invalid && invalid_case == InvalidCase::NodeFields;
            let invalid_indexed = draw_invalid && invalid_case == InvalidCase::Indexed;
            let invalid_parse = draw_invalid && invalid_case == InvalidCase::ParseNode;

            let fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };
            let default_value = tc.draw(booleans());
            let node_fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };

            let n_feats = tc.draw(gen_usize_between(1, 10));
            let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));

            let n_nodes = if invalid_parse {
                tc.draw(gen_usize_between(1, 10))
            } else {
                tc.draw(gen_usize_with_max(10))
            };
            let invalid_idx = if invalid_parse { tc.draw(gen_usize_with_max(n_nodes - 1)) } else { 0 };

            let mut indexed = Vec::new();
            let mut nodes = Vec::new();
            for _ in 0..n_nodes {
                indexed.push(tc.draw(gen_fields()));
                if tc.draw(booleans()) {
                    let node = tc.draw(gen_input_node(Some(&feat_ids)));
                    let input_node = LogicNode::Input(node);
                    nodes.push(input_node);
                } else {
                    let gate_node = LogicNode::Gate(tc.draw(gen_gate_node()));
                    nodes.push(gate_node);
                }
            }

            let past_default = !invalid_default;
            let past_fields = past_default && !invalid_fields;
            let past_indexed = past_fields && !invalid_indexed;

            let expected_net = LogicNet { nodes: nodes.clone(), default_value };
            let mut mock_deps = MockParseLogicNetDeps::new();

            mock_deps.expect_bool()
                .times(1)
                .withf(|_, keys, default| *keys == ["default_value", "default"] && !default)
                .return_const(if invalid_default { Err(String::new()) } else { Ok(default_value) });

            mock_deps.expect_child_fields()
                .times(usize::from(past_default))
                .withf(|_, keys| *keys == ["nodes", "logic_nodes"])
                .return_const(if invalid_fields { Err(String::new()) } else { Ok(node_fields) });

            mock_deps.expect_indexed_nodes_fields()
                .times(usize::from(past_fields))
                .return_const(if invalid_indexed { Err(String::new()) } else { Ok(indexed) });

            let parse_idx = Cell::new(0);
            let nodes_for_parse = nodes.clone();
            mock_deps.expect_parse_logic_node()
                .times(if invalid_parse { invalid_idx + 1 } else if past_indexed { n_nodes } else { 0 })
                .returning(move |_| {
                    let idx = parse_idx.get();

                    if invalid_parse && idx == invalid_idx {
                        return Err(String::new())
                    }

                    parse_idx.set(idx + 1);
                    Ok(nodes_for_parse[idx].clone())
                });

            mock_deps.expect_validate_logic_net()
                .times(usize::from(past_indexed && !invalid_parse))
                .withf({
                    let expected_nodes = nodes.clone();
                    let expected_feat_ids = feat_ids.clone();
                    move |actual_nodes, actual_feat_ids| {
                        if *actual_nodes != expected_nodes { return false }
                        *actual_feat_ids == expected_feat_ids
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Validate { Err(String::new()) } else { Ok(()) });

            let result = _parse_logic_net(&mock_deps, fields, &feat_ids);
            TestContext { expected_net, result }
        }

        #[hegel::test]
        fn test_parse_logic_net(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_net));
        }

        #[hegel::test]
        fn test_parse_logic_net_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_logic_penalties_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_penalties: LogicPenalties,
            result: Result<LogicPenalties, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_f64 = draw_invalid && tc.draw(booleans());
            let invalid_non_neg = draw_invalid && !invalid_f64;
            let fail_idx = tc.draw(gen_usize_with_max(6));

            let expected_penalties = LogicPenalties {
                node: tc.draw(gen_f64()),
                input: tc.draw(gen_f64()),
                gate: tc.draw(gen_f64()),
                recurrence: tc.draw(gen_f64()),
                feedforward: tc.draw(gen_f64()),
                used_feat: tc.draw(gen_f64()),
                unused_feat: tc.draw(gen_f64())
            };
            let fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };
            let values = [expected_penalties.node, expected_penalties.input, expected_penalties.gate, expected_penalties.recurrence, expected_penalties.feedforward, expected_penalties.used_feat, expected_penalties.unused_feat];
            let keys: [&[&str]; 7] = [
                &["node", "node_penalty"],
                &["input", "input_penalty"],
                &["gate", "gate_penalty"],
                &["recurrence", "recurrence_penalty", "rec", "rec_penalty"],
                &["feedforward", "feedforward_penalty"],
                &["used_feat", "used_feat_penalty", "used_feature", "used_feature_penalty"],
                &["unused_feat", "unused_feature"]
            ];
            let labels = ["node penalty", "input penalty", "gate penalty", "recurrence", "feedforward", "used feature", "unused feature"];

            let mut mock_deps = MockParseLogicPenaltiesDeps::new();
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

            let result = _parse_logic_penalties(&mock_deps, fields);
            TestContext { expected_penalties, result }
        }

        #[hegel::test]
        fn test_parse_logic_penalties(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_penalties));
        }

        #[hegel::test]
        fn test_parse_logic_penalties_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}