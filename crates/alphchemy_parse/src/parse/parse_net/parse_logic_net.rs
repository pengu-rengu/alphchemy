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
        super::parse_net::indexed_nodes_fields(fields)
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

pub fn parse_logic_penalties(fields: Option<Fields>) -> Result<LogicPenalties, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let node = fields.f64(&["node", "node_penalty"], 0.0)?;
    let input = fields.f64(&["input", "input_penalty"], 0.0)?;
    let gate = fields.f64(&["gate", "gate_penalty"], 0.0)?;
    let recurrence = fields.f64(&["recurrence", "recurrence_penalty", "rec", "rec_penalty"], 0.0)?;
    let feedforward = fields.f64(&["feedforward", "feedforward_penalty"], 0.0)?;
    let used_feat = fields.f64(&["used_feat", "used_feat_penalty", "used_feature", "used_feature_penalty"], 0.0)?;
    let unused_feat = fields.f64(&["unused_feat", "unused_feature"], 0.0)?;

    expect_non_neg(node, "node penalty")?;
    expect_non_neg(input, "input penalty")?;
    expect_non_neg(gate, "gate penalty")?;
    expect_non_neg(recurrence, "recurrence")?;
    expect_non_neg(feedforward, "feedforward")?;
    expect_non_neg(used_feat, "used feature")?;
    expect_non_neg(unused_feat, "unused feature")?;

    let penalties = LogicPenalties {
        node, input, gate, recurrence, feedforward, used_feat, unused_feat
    };
    Ok(penalties)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parse::parse::Entry;
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

    #[hegel::composite]
    fn gen_fields(tc: TestCase) -> Fields {
        let n_entries = tc.draw(gen_usize_with_max(5));
        let mut entries = Vec::new();
        for _ in 0..n_entries {
            let key = tc.draw(gen_text());
            let inline = if tc.draw(booleans()) { Some(tc.draw(gen_text())) } else { None };
            let entry = Entry { key, inline, child_lines: Vec::new() };
            entries.push(entry);
        }
        Fields { entries }
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

            let threshold = if tc.draw(booleans()) { Some(tc.draw(gen_f64())) } else { None };
            let feat_id = if tc.draw(booleans()) { Some(tc.draw(gen_text())) } else { None };

            let expected_node = InputNode {
                threshold: threshold.clone(),
                feat_id: feat_id.clone(),
                value: false
            };

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseLogicNetDeps::new();

            mock_deps.expect_option_f64()
                .times(1)
                .withf(|_, keys| *keys == ["threshold"])
                .return_const(if invalid_threshold { Err(String::new()) } else { Ok(threshold) });

            mock_deps.expect_option_string()
                .times(usize::from(!invalid_threshold))
                .withf(|_, keys| *keys == ["feat_id", "feature_id"])
                .return_const(if draw_invalid && !invalid_threshold { Err(String::new()) } else { Ok(feat_id) });

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

            let gate = if tc.draw(booleans()) {
                Some(tc.draw(sampled_from(vec![
                    Gate::And, Gate::Or, Gate::Xor, Gate::Nand, Gate::Nor, Gate::Xnor
                ])))
            } else { None };
            let in1_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
            let in2_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };

            let expected_node = GateNode { gate, in1_idx, in2_idx, value: false };

            let fields = tc.draw(gen_fields());
            let mut mock_deps = MockParseLogicNetDeps::new();

            mock_deps.expect_parse_option_gate()
                .times(1)
                .return_const(if invalid_gate { Err(String::new()) } else { Ok(gate) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_gate))
                .withf(|_, keys| *keys == ["in1_idx", "in1", "input1"])
                .return_const(if invalid_in1 { Err(String::new()) } else { Ok(in1_idx) });

            mock_deps.expect_option_usize()
                .times(usize::from(!invalid_gate && !invalid_in1))
                .withf(|_, keys| *keys == ["in2_idx", "in2", "input2"])
                .return_const(if invalid_in2 { Err(String::new()) } else { Ok(in2_idx) });

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

            let threshold = if tc.draw(booleans()) { Some(tc.draw(gen_f64())) } else { None };
            let feat_id = if tc.draw(booleans()) { Some(tc.draw(gen_text())) } else { None };
            let input_node = InputNode { threshold, feat_id, value: tc.draw(booleans()) };

            let gate = if tc.draw(booleans()) {
                Some(tc.draw(sampled_from(vec![
                    Gate::And, Gate::Or, Gate::Xor, Gate::Nand, Gate::Nor, Gate::Xnor
                ])))
            } else { None };
            let in1_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
            let in2_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
            let gate_node = GateNode { gate, in1_idx, in2_idx, value: tc.draw(booleans()) };

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
            let invalid_feat = draw_invalid && invalid_case == InvalidCase::FeatId;
            let invalid_in1 = draw_invalid && invalid_case == InvalidCase::In1Idx;

            let n_feats = tc.draw(gen_usize_between(1, 10));
            let feat_ids = tc.draw(gen_vec(gen_text(), n_feats));

            let threshold = if tc.draw(booleans()) { Some(tc.draw(gen_f64())) } else { None };
            let feat_id = if invalid_feat {
                let missing_id = tc.draw(gen_text());
                let is_valid = feat_ids.contains(&missing_id);
                tc.assume(!is_valid);
                Some(missing_id)
            } else if tc.draw(booleans()) {
                Some(tc.draw(sampled_from(&feat_ids)))
            } else { None };
            let input_node = InputNode { threshold, feat_id, value: tc.draw(booleans()) };

            let gate = if tc.draw(booleans()) {
                Some(tc.draw(sampled_from(vec![
                    Gate::And, Gate::Or, Gate::Xor, Gate::Nand, Gate::Nor, Gate::Xnor
                ])))
            } else { None };
            let in1_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
            let in2_idx = if tc.draw(booleans()) { Some(tc.draw(gen_usize())) } else { None };
            let gate_node = GateNode { gate, in1_idx, in2_idx, value: tc.draw(booleans()) };

            let nodes = vec![LogicNode::Input(input_node), LogicNode::Gate(gate_node)];
            let mut mock_deps = MockParseLogicNetDeps::new();

            mock_deps.expect_feat_id_set()
                .times(1)
                .withf({
                    let expected_feat_ids = feat_ids.clone();
                    move |ids| *ids == expected_feat_ids
                })
                .return_const(feat_ids.iter().cloned().collect::<HashSet<_>>());

            mock_deps.expect_validate_idx()
                .times(usize::from(!invalid_feat))
                .withf(|_, _, field| field == "in1_idx")
                .return_const(if invalid_in1 { Err(String::new()) } else { Ok(()) });

            mock_deps.expect_validate_idx()
                .times(usize::from(!invalid_feat && !invalid_in1))
                .withf(|_, _, field| field == "in2_idx")
                .return_const(if draw_invalid && invalid_case == InvalidCase::In2Idx { Err(String::new()) } else { Ok(()) });

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
}