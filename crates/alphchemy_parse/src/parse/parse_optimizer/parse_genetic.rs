use std::collections::HashMap;

use alphchemy_engine::actions::actions::Action;
use alphchemy_engine::optimizer::optimizer::Objective;
use alphchemy_engine::optimizer::genetic::GeneticOpt;
use alphchemy_engine::experiment::backtest::BacktestMetric;
use super::super::parse::Fields;
use super::super::parse_experiment::parse_backtest::parse_metric;

const MAX_POP_SIZE: usize = 500;
const MAX_SEQ_LEN: usize = 100;

fn action_for_label(actions_list: &[Action], label: &str) -> Result<Action, String> {
    for action in actions_list {
        if action.label() == label {
            return Ok(action.clone());
        }
    }

    Err(format!("invalid action weight label: {label}"))
}

fn parse_action_weights(fields: Option<Fields>, actions_list: &[Action]) -> Result<HashMap<Action, f64>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut action_weights = HashMap::new();

    for entry in &fields.entries {
        let action = action_for_label(actions_list, &entry.key)?;
        let weight_text = entry.inline.as_deref().ok_or(format!("action weight {} must have a value", entry.key))?;
        let weight = weight_text.parse::<f64>().map_err(|_| format!("invalid action weight: {weight_text}"))?;

        if !weight.is_finite() || weight < 0.0 {
            return Err(format!("action weight {} must be finite and >= 0.0", entry.key));
        }

        if action_weights.insert(action, weight).is_some() {
            return Err(format!("duplicate action weight: {}", entry.key));
        }
    }

    let mut total_weight = 0.0;

    for action in actions_list {
        let maybe_weight = action_weights.get(action);
        let weight = maybe_weight.copied().unwrap_or(1.0);
        total_weight += weight;
    }

    if total_weight == 0.0 {
        return Err("at least one action weight must be > 0.0".to_string());
    }

    Ok(action_weights)
}

pub fn parse_opt(fields: Option<Fields>, actions_list: &[Action]) -> Result<GeneticOpt, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let opt_type = fields.string(&["type"], "genetic")?;
    if opt_type.as_str() != "genetic" {
        return Err(format!("invalid optimizer type: {opt_type}"));
    }

    let pop_size = fields.usize(&["pop_size"], 100)?;
    let seq_len = fields.usize(&["seq_len"], 25)?;
    let n_elites = fields.usize(&["n_elites"], 5)?;
    let mut_rate = fields.f64(&["mut_rate"], 0.3)?;
    let cross_rate = fields.f64(&["cross_rate"], 0.3)?;
    let tourn_size = fields.usize(&["tourn_size"], 3)?;

    if pop_size == 0 {
        return Err("Optimizer population size must be > 0".to_string())
    }
    if pop_size > MAX_POP_SIZE {
        return Err(format!("Population size must be <= {MAX_POP_SIZE}"))
    }

    if seq_len == 0 {
        return Err("Optimizer sequence length must be > 0".to_string())
    }
    if seq_len > MAX_SEQ_LEN {
        return Err(format!("Optimizer sequence length must be <= {MAX_SEQ_LEN}"))
    }

    if n_elites > pop_size {
        return Err("Optimizer number of elites must be > 0 and < population size".to_string());
    }

    if !(0.0..=1.0).contains(&mut_rate) {
        return Err("mut_rate must be 0.0 - 1.0".to_string());
    }

    if !(0.0..=1.0).contains(&cross_rate) {
        return Err("cross_rate must be 0.0 - 1.0".to_string());
    }

    if tourn_size == 0 {
        return Err("tourn_size must be 1 - pop_size".to_string());
    }
    if tourn_size > pop_size {
        return Err("tourn_size must be 1 - pop_size".to_string());
    }

    let maybe_objective_fields = fields.child_fields(&["objectives"])?;

    let objectives = match maybe_objective_fields {
        Some(objective_fields) if !objective_fields.entries.is_empty() => {
            let mut objectives = Vec::with_capacity(objective_fields.entries.len());

            for entry in &objective_fields.entries {
                let metric = parse_metric(&entry.key)?;
                let weight_text = entry.inline.as_deref().ok_or(format!("objective {} must have a weight", entry.key))?;
                let weight = weight_text.parse::<f64>().map_err(|_| format!("invalid weight: {weight_text}"))?;
                objectives.push(Objective { metric, weight });
            }

            objectives
        },
        Some(_) | None => vec![Objective { metric: BacktestMetric::ExcessSharpe, weight: 1.0 }]
    };

    let action_weight_fields = fields.child_fields(&["action_weights"])?;
    let action_weights = parse_action_weights(action_weight_fields, actions_list)?;
    let random_seed = fields.option_usize(&["random_seed"])?;

    Ok( GeneticOpt { pop_size, seq_len, n_elites, mut_rate, cross_rate, tourn_size, objectives, action_weights, random_seed })
}
