use alphchemy_engine::features::features::Feature;
use alphchemy_engine::actions::decision_actions::DecisionActions;
use super::super::parse::Fields;
use super::parse_actions::ActionsShared;

#[cfg(test)]
use mockall::automock;

#[cfg_attr(test, automock)]
trait ParseDecisionActionsDeps {
    fn bool<'a>(&self, fields: &Fields, keys: &[&'a str], default: bool) -> Result<bool, String> {
        fields.bool(keys, default)
    }

    fn parse_actions_shared(&self, fields: &Fields, feats: &[Feature], expected_type: &str) -> Result<ActionsShared, String> {
        super::parse_actions::parse_actions_shared(fields, feats, expected_type)
    }

    fn parse_decision_actions(&self, fields: Option<Fields>, feats: &[Feature]) -> Result<DecisionActions, String> {
        _parse_decision_actions(&ParseDecisionActionsDepsImpl, fields, feats)
    }
}

struct ParseDecisionActionsDepsImpl;
impl ParseDecisionActionsDeps for ParseDecisionActionsDepsImpl {}

fn _parse_decision_actions<T>(deps: &T, fields: Option<Fields>, feats: &[Feature]) -> Result<DecisionActions, String> where T: ParseDecisionActionsDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let shared = deps.parse_actions_shared(&fields, feats, "decision")?;
    let allow_refs = deps.bool(&fields, &["allow_refs", "allow_ref_nodes", "allow_references", "allow_reference_nodes"], false)?;

    Ok(DecisionActions {
        meta_actions: shared.meta_actions,
        thresholds: shared.thresholds,
        n_thresholds: shared.n_thresholds,
        feat_order: shared.feat_order,
        allow_refs
    })
}

pub fn parse_decision_actions(fields: Option<Fields>, feats: &[Feature]) -> Result<DecisionActions, String> {
    ParseDecisionActionsDepsImpl.parse_decision_actions(fields, feats)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parse::parse::tests::gen_fields;
    use crate::parse::parse_actions::tests::gen_actions_shared;
    use alphchemy_engine::features::features::Constant;
    use alphchemy_test_utils::{gen_f64, gen_usize_with_max};
    use hegel::{TestCase, generators::booleans};

    #[derive(Debug)]
    struct TestContext {
        expected_actions: DecisionActions,
        result: Result<DecisionActions, String>
    }

    #[hegel::composite]
    fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
        let invalid_shared = draw_invalid && tc.draw(booleans());
        let invalid_refs = draw_invalid && !invalid_shared;

        let maybe_fields = if tc.draw(booleans()) { Some(tc.draw(gen_fields())) } else { None };
        let fields = maybe_fields.clone().unwrap_or(Fields { entries: Vec::new() });
        let shared = tc.draw(gen_actions_shared());
        let allow_refs = tc.draw(booleans());

        let n_feats = tc.draw(gen_usize_with_max(10));
        let mut feats = Vec::new();
        for i in 0..n_feats {
            let feat_id = i.to_string();
            let constant = Constant { id: feat_id, constant: tc.draw(gen_f64()) };
            let feat = Feature::Constant(constant);
            feats.push(feat);
        }

        let expected_actions = DecisionActions {
            meta_actions: shared.meta_actions.clone(),
            thresholds: shared.thresholds.clone(),
            n_thresholds: shared.n_thresholds,
            feat_order: shared.feat_order.clone(),
            allow_refs
        };

        let mut mock_deps = MockParseDecisionActionsDeps::new();

        mock_deps.expect_parse_actions_shared()
            .times(1)
            .withf({
                let expected_fields = fields.clone();
                move |actual_fields, _feats, expected_type| {
                    *actual_fields == expected_fields && expected_type == "decision"
                }
            })
            .return_const(if invalid_shared { Err(String::new()) } else { Ok(shared) });

        mock_deps.expect_bool()
            .times(usize::from(!invalid_shared))
            .withf({
                let expected_fields = fields.clone();
                move |actual_fields, keys, default| {
                    *actual_fields == expected_fields && *keys == ["allow_refs", "allow_ref_nodes", "allow_references", "allow_reference_nodes"] && !default
                }
            })
            .return_const(if invalid_refs { Err(String::new()) } else { Ok(allow_refs) });

        let result = _parse_decision_actions(&mock_deps, maybe_fields, &feats);
        TestContext { expected_actions, result }
    }

    #[hegel::test]
    fn test_parse_decision_actions(tc: TestCase) {
        let ctx = tc.draw(gen_context(false));
        assert_eq!(ctx.result, Ok(ctx.expected_actions));
    }

    #[hegel::test]
    fn test_parse_decision_actions_invalid(tc: TestCase) {
        let ctx = tc.draw(gen_context(true));
        assert!(ctx.result.is_err());
    }
}