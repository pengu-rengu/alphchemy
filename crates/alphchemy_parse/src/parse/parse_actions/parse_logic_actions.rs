use alphchemy_engine::features::features::Feature;
use alphchemy_engine::actions::logic_actions::LogicActions;
use alphchemy_engine::network::logic_net::Gate;
use super::super::parse::Fields;
use super::super::parse_net::parse_logic_net::parse_gate;
use super::parse_actions::parse_actions_shared;

fn parse_gates(texts: &[String]) -> Result<Vec<Gate>, String> {
    let mut gates = Vec::with_capacity(texts.len());
    for text in texts {
        let gate = parse_gate(text)?;
        gates.push(gate);
    }

    Ok(gates)
}

pub fn parse_logic_actions(fields: Option<Fields<'_>>, feats: &[Feature]) -> Result<LogicActions, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let shared = parse_actions_shared(&fields, feats, "logic")?;
    let allow_recurrence = fields.bool(&["allow_recurrence", "allow_rec", "allow_recurrent_nodes"], false)?;
    let gate_texts = fields.string_list(&["allowed_gates"], vec!["and".to_string(), "or".to_string(), "xor".to_string()])?;
    let allowed_gates = parse_gates(&gate_texts)?;

    let actions = LogicActions {
        meta_actions: shared.meta_actions,
        thresholds: shared.thresholds,
        n_thresholds: shared.n_thresholds,
        feat_order: shared.feat_order,
        allow_recurrence,
        allowed_gates
    };
    Ok(actions)
}
