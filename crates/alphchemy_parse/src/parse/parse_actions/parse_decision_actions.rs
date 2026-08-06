use alphchemy_engine::features::features::Feature;
use alphchemy_engine::actions::decision_actions::DecisionActions;
use super::super::parse::Fields;
use super::parse_actions::parse_actions_shared;

pub fn parse_decision_actions(fields: Option<Fields>, feats: &[Feature]) -> Result<DecisionActions, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let shared = parse_actions_shared(&fields, feats, "decision")?;
    let allow_refs = fields.bool(&["allow_refs", "allow_ref_nodes", "allow_references", "allow_reference_nodes"], false)?;

    let actions = DecisionActions {
        meta_actions: shared.meta_actions,
        thresholds: shared.thresholds,
        n_thresholds: shared.n_thresholds,
        feat_order: shared.feat_order,
        allow_refs
    };
    Ok(actions)
}
