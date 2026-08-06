use alphchemy_engine::optimizer::optimizer::StopConds;
use super::super::parse::Fields;

const MAX_ITERS_CAP: usize = 1000;

pub fn parse_stop_conds(fields: Option<Fields>) -> Result<StopConds, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

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
