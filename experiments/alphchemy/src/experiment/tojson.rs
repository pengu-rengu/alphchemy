use serde_json::{json, to_value, Value};

use crate::actions::actions::Action;
use crate::optimizer::optimizer::{Improvement, ItersState};
use crate::experiment::backtest::BacktestResults;
use crate::experiment::experiment::{FoldResults, ExperimentResults};

pub fn improvements_json(imps: &[Improvement]) -> Value {
    let convert_imp = |imp: &Improvement| json!({
        "iter": imp.iter,
        "score": imp.score
    });
    let imps_json: Vec<Value> = imps.iter().map(convert_imp).collect();

    Value::Array(imps_json)
}

pub fn opt_results_json(results: &ItersState) -> Value {
    let convert_action = |action: &Action| to_value(action).unwrap_or_default();
    let best_seq = results.best_seq.iter().map(convert_action).collect::<Vec<Value>>();

    json!({
        "iters": results.iters,
        "best_seq": best_seq,
        "train_improvements": improvements_json(&results.train_improvements),
        "val_improvements": improvements_json(&results.val_improvements)
    })
}

pub fn backtest_results_json(results: &BacktestResults) -> Value {
    let state = &results.final_state;

    json!({
        "is_invalid": results.is_invalid,
        "excess_sharpe": results.excess_sharpe,
        "mean_hold_time": results.mean_hold_time,
        "std_hold_time": results.std_hold_time,
        "entries": state.entries,
        "total_exits": state.total_exits,
        "signal_exits": state.signal_exits,
        "stop_loss_exits": state.stop_loss_exits,
        "take_profit_exits": state.take_profit_exits,
        "max_hold_exits": state.max_hold_exits
    })
}

pub fn fold_results_json(results: &FoldResults) -> Value {
    json!({
        "start_idx": results.start_idx,
        "end_idx": results.end_idx,
        "opt_results": opt_results_json(&results.opt_results),
        "train_results": backtest_results_json(&results.train_results),
        "val_results": backtest_results_json(&results.val_results),
        "test_results": backtest_results_json(&results.test_results)
    })
}

pub fn experiment_results_json(results: &ExperimentResults) -> Value {
    let folds: Vec<Value> = results.fold_results.iter().map(fold_results_json).collect();

    json!({
        "overall_excess_sharpe": results.overall_excess_sharpe,
        "invalid_frac": results.invalid_frac,
        "fold_results": folds
    })
}
