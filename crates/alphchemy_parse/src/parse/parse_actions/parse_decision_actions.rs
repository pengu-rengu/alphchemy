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
