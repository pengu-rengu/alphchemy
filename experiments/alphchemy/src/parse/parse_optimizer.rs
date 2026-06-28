use crate::optimizer::optimizer::StopConds;
use crate::optimizer::genetic::GeneticOpt;
use super::parse::Fields;

// === Parsing ===

pub fn parse_stop_conds(fields: &Fields) -> Result<StopConds, String> {
    let max_iters = fields.usize(&["max_iters"], 6)?;
    let train_patience = fields.usize(&["train_patience"], 3)?;
    let val_patience = fields.usize(&["val_patience"], 3)?;

    let stop_conds = StopConds { max_iters, train_patience, val_patience };
    Ok(stop_conds)
}

pub fn parse_opt(fields: &Fields) -> Result<GeneticOpt, String> {
    let opt_type = fields.string(&["type"], "genetic");
    if opt_type.as_str() != "genetic" {
        return Err(format!("invalid optimizer type: {opt_type}"));
    }

    let pop_size = fields.usize(&["pop_size"], 12)?;
    let seq_len = fields.usize(&["seq_len"], 8)?;
    let n_elites = fields.usize(&["n_elites"], 2)?;
    let mut_rate = fields.f64(&["mut_rate"], 0.1)?;
    let cross_rate = fields.f64(&["cross_rate"], 0.7)?;
    let tourn_size = fields.usize(&["tourn_size"], 3)?;

    let opt = GeneticOpt { pop_size, seq_len, n_elites, mut_rate, cross_rate, tourn_size };
    Ok(opt)
}

// === Validation ===

pub fn validate_stop_conds(stop_conds: &StopConds) -> Result<(), String> {
    if stop_conds.max_iters == 0 {
        return Err("max_iters must be > 0".to_string());
    }
    Ok(())
}

pub fn validate_opt(opt: &GeneticOpt) -> Result<(), String> {
    if opt.pop_size == 0 {
        return Err("pop_size must be > 0".to_string());
    }
    if opt.seq_len == 0 {
        return Err("seq_len must be > 0".to_string());
    }
    if opt.n_elites > opt.pop_size {
        return Err("n_elites must be 0 - population size".to_string());
    }

    let mut_in_range = (0.0..=1.0).contains(&opt.mut_rate);
    if !mut_in_range {
        return Err("mut_rate must be 0.0 - 1.0".to_string());
    }

    let cross_in_range = (0.0..=1.0).contains(&opt.cross_rate);
    if !cross_in_range {
        return Err("cross_rate must be 0.0 - 1.0".to_string());
    }

    if opt.tourn_size == 0 {
        return Err("tourn_size must be 1 - pop_size".to_string());
    }
    if opt.tourn_size > opt.pop_size {
        return Err("tourn_size must be 1 - pop_size".to_string());
    }

    Ok(())
}
