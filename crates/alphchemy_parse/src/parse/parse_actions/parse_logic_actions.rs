use alphchemy_engine::features::features::Feature;
use alphchemy_engine::actions::logic_actions::LogicActions;
use alphchemy_engine::network::logic_net::Gate;
use super::super::parse::Fields;
use super::parse_actions::ActionsShared;

#[cfg(test)]
use mockall::automock;

#[cfg_attr(test, automock)]
trait ParseLogicActionsDeps {
    fn bool<'a>(&self, fields: &Fields, keys: &[&'a str], default: bool) -> Result<bool, String> {
        fields.bool(keys, default)
    }

    fn string_list<'a>(&self, fields: &Fields, keys: &[&'a str], default: Vec<String>) -> Result<Vec<String>, String> {
        fields.string_list(keys, default)
    }

    fn parse_actions_shared(&self, fields: &Fields, feats: &[Feature], expected_type: &str) -> Result<ActionsShared, String> {
        super::parse_actions::parse_actions_shared(fields, feats, expected_type)
    }

    fn parse_gate(&self, text: &str) -> Result<Gate, String> {
        super::super::parse_net::parse_logic_net::parse_gate(text)
    }

    fn parse_gates(&self, texts: &[String]) -> Result<Vec<Gate>, String> {
        _parse_gates(&ParseLogicActionsDepsImpl, texts)
    }

    fn parse_logic_actions(&self, fields: Option<Fields>, feats: &[Feature]) -> Result<LogicActions, String> {
        _parse_logic_actions(&ParseLogicActionsDepsImpl, fields, feats)
    }
}

struct ParseLogicActionsDepsImpl;
impl ParseLogicActionsDeps for ParseLogicActionsDepsImpl {}

fn _parse_gates<T>(deps: &T, texts: &[String]) -> Result<Vec<Gate>, String> where T: ParseLogicActionsDeps {
    let mut gates = Vec::with_capacity(texts.len());
    for text in texts {
        let gate = deps.parse_gate(text)?;
        gates.push(gate);
    }

    Ok(gates)
}

fn _parse_logic_actions<T>(deps: &T, fields: Option<Fields>, feats: &[Feature]) -> Result<LogicActions, String> where T: ParseLogicActionsDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let shared = deps.parse_actions_shared(&fields, feats, "logic")?;
    let allow_recurrence = deps.bool(&fields, &["allow_recurrence", "allow_rec", "allow_recurrent_nodes"], false)?;
    let gate_texts = deps.string_list(&fields, &["allowed_gates"], vec!["and".to_string(), "or".to_string(), "xor".to_string()])?;
    let allowed_gates = deps.parse_gates(&gate_texts)?;

    Ok(LogicActions {
        meta_actions: shared.meta_actions,
        thresholds: shared.thresholds,
        n_thresholds: shared.n_thresholds,
        feat_order: shared.feat_order,
        allow_recurrence,
        allowed_gates
    })
}

pub fn parse_logic_actions(fields: Option<Fields>, feats: &[Feature]) -> Result<LogicActions, String> {
    ParseLogicActionsDepsImpl.parse_logic_actions(fields, feats)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parse::parse::tests::gen_fields;
    use crate::parse::parse_actions::tests::gen_actions_shared;
    use alphchemy_engine::features::features::Constant;
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::{TestCase, generators::{booleans, sampled_from}};
    use mockall::predicate::in_iter;
    use std::cell::Cell;

    #[hegel::composite]
    fn gen_gate(tc: TestCase) -> Gate {
        tc.draw(sampled_from(&[Gate::And, Gate::Or, Gate::Xor, Gate::Nand, Gate::Nor, Gate::Xnor]))
    }

    mod parse_gates_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_gates: Vec<Gate>,
            result: Result<Vec<Gate>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let n_gates = if draw_invalid {
                tc.draw(gen_usize_between(1, 10))
            } else {
                tc.draw(gen_usize_with_max(10))
            };
            let invalid_idx = if draw_invalid { tc.draw(gen_usize_with_max(n_gates - 1)) } else { 0 };

            let texts = tc.draw(gen_vec(gen_text(), n_gates));
            let expected_gates = tc.draw(gen_vec(gen_gate(), n_gates));

            let mut mock_deps = MockParseLogicActionsDeps::new();
            let parse_idx = Cell::new(0);
            let gates_for_parse = expected_gates.clone();
            mock_deps.expect_parse_gate()
                .times(if draw_invalid { invalid_idx + 1 } else { n_gates })
                .with(in_iter(texts.clone()))
                .returning(move |_| {
                    let idx = parse_idx.get();
                    if draw_invalid && idx == invalid_idx {
                        return Err(String::new())
                    }
                    parse_idx.set(idx + 1);
                    Ok(gates_for_parse[idx])
                });

            let result = _parse_gates(&mock_deps, &texts);
            TestContext { expected_gates, result }
        }

        #[hegel::test]
        fn test_parse_gates(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_gates));
        }

        #[hegel::test]
        fn test_parse_gates_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod parse_logic_actions_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { Shared, Recurrence, GateTexts, ParseGates }

        #[derive(Debug)]
        struct TestContext {
            expected_actions: LogicActions,
            result: Result<LogicActions, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(&[
                InvalidCase::Shared, InvalidCase::Recurrence, InvalidCase::GateTexts, InvalidCase::ParseGates
            ]));

            let maybe_fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };
            let fields = maybe_fields.clone().unwrap_or(Fields { entries: Vec::new() });
            let shared = tc.draw(gen_actions_shared());

            let allow_recurrence = tc.draw(booleans());
            let n_gates = tc.draw(gen_usize_with_max(10));
            let gate_texts = tc.draw(gen_vec(gen_text(), n_gates));
            let allowed_gates = tc.draw(gen_vec(gen_gate(), n_gates));

            let n_feats = tc.draw(gen_usize_with_max(10));
            let mut feats = Vec::new();
            for i in 0..n_feats {
                let feat_id = i.to_string();
                let constant = Constant { id: feat_id, constant: tc.draw(gen_f64()) };
                let feat = Feature::Constant(constant);
                feats.push(feat);
            }

            let expected_actions = LogicActions {
                meta_actions: shared.meta_actions.clone(),
                thresholds: shared.thresholds.clone(),
                n_thresholds: shared.n_thresholds,
                feat_order: shared.feat_order.clone(),
                allow_recurrence,
                allowed_gates: allowed_gates.clone()
            };

            let mut mock_deps = MockParseLogicActionsDeps::new();

            mock_deps.expect_parse_actions_shared()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, _feats, expected_type| {
                        *actual_fields == expected_fields && expected_type == "logic"
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Shared {
                    Err(String::new())
                } else { Ok(shared) });

            mock_deps.expect_bool()
                .times(usize::from(!draw_invalid || invalid_case != InvalidCase::Shared))
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, keys, default| {
                        *actual_fields == expected_fields && *keys == ["allow_recurrence", "allow_rec", "allow_recurrent_nodes"] && !default
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::Recurrence {
                    Err(String::new())
                } else { Ok(allow_recurrence) });

            mock_deps.expect_string_list()
                .times(usize::from(!draw_invalid || ![InvalidCase::Shared, InvalidCase::Recurrence].contains(&invalid_case)))
                .withf({
                    let expected_fields = fields.clone();
                    move |actual_fields, keys, default| {
                        *actual_fields == expected_fields && *keys == ["allowed_gates"] && *default == ["and", "or", "xor"]
                    }
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::GateTexts {
                    Err(String::new())
                } else { Ok(gate_texts.clone()) });

            mock_deps.expect_parse_gates()
                .times(usize::from(!draw_invalid || invalid_case == InvalidCase::ParseGates))
                .withf({
                    let expected_texts = gate_texts.clone();
                    move |texts| *texts == expected_texts
                })
                .return_const(if draw_invalid && invalid_case == InvalidCase::ParseGates {
                    Err(String::new())
                } else { Ok(allowed_gates) });

            let result = _parse_logic_actions(&mock_deps, maybe_fields, &feats);
            TestContext { expected_actions, result }
        }

        #[hegel::test]
        fn test_parse_logic_actions(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok(ctx.expected_actions));
        }

        #[hegel::test]
        fn test_parse_logic_actions_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}
