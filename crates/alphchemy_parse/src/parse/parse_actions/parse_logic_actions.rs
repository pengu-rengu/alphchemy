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
    use alphchemy_test_utils::{gen_text, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::{TestCase, generators::sampled_from};
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
}
