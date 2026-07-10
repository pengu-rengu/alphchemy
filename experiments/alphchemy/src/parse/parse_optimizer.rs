
use crate::optimizer::optimizer::{Objective, StopConds};
use crate::optimizer::genetic::GeneticOpt;
use crate::experiment::backtest::BacktestMetric;
use super::parse::Fields;
use super::parse_experiment::parse_metric;

const MAX_ITERS_CAP: usize = 1000;
const MAX_POP_SIZE: usize = 500;
const MAX_SEQ_LEN: usize = 100;

pub fn parse_stop_conds(fields: &Fields) -> Result<StopConds, String> {
    let max_iters = fields.usize(&["max_iters"], 100)?;
    let train_patience = fields.usize(&["train_patience"], 100)?;
    let val_patience = fields.usize(&["val_patience"], 100)?;

    if max_iters > MAX_ITERS_CAP {
        return Err(format!("Stop conditions max iterations must be <= {MAX_ITERS_CAP}"));
    }

    if max_iters == 0 {
        return Err("Stop conditions max iterations must be > 0".to_string());
    }

    let stop_conds = StopConds { max_iters, train_patience, val_patience };
    Ok(stop_conds)
}

pub fn parse_opt(fields: &Fields) -> Result<GeneticOpt, String> {
    let opt_type = fields.string(&["type"], "genetic");
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

    let obj_fields = fields.child_fields(&["objectives"]);
    let mut objectives = Vec::with_capacity(obj_fields.entries.len());
    for entry in &obj_fields.entries {
        let metric = parse_metric(entry.key)?;
        let weight_text = entry.inline.ok_or(format!("objective {} must have a weight", entry.key))?;
        let weight = weight_text.parse::<f64>().map_err(|_| format!("invalid weight: {weight_text}"))?;
        objectives.push(Objective { metric, weight });
    }
    if objectives.is_empty() {
        objectives.push(Objective { metric: BacktestMetric::ExcessSharpe, weight: 1.0 });
    }

    let random_seed = fields.opt_usize(&["random_seed"])?;

    let opt = GeneticOpt { pop_size, seq_len, n_elites, mut_rate, cross_rate, tourn_size, objectives, random_seed };
    Ok(opt)
}
