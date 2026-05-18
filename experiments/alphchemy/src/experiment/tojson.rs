use serde_json::{Value, json, to_value};

use crate::actions::actions::Action;
use crate::optimizer::optimizer::{Improvement, ItersState};
use crate::experiment::backtest::BacktestResults;
use crate::experiment::experiment::FoldResults;

pub fn improvements_json(imps: &[Improvement]) -> Value {
    let convert_imp = |imp: &Improvement| json!({
        "iter": imp.iter,
        "score": imp.score
    });
    let imps_json: Vec<Value> = imps.iter().map(convert_imp).collect();

    Value::Array(imps_json)
}

pub fn opt_results_json(iters_state: &ItersState) -> Value {
    let convert_action = |action: &Action| to_value(action).unwrap_or_default();
    let best_train_seq = iters_state.best_train_seq.iter().map(convert_action).collect::<Vec<Value>>();
    let best_val_seq = iters_state.best_val_seq.iter().map(convert_action).collect::<Vec<Value>>();

    json!({
        "iters": iters_state.iters,
        "best_train_seq": best_train_seq,
        "best_val_seq": best_val_seq,
        "train_improvements": improvements_json(&iters_state.train_improvements),
        "val_improvements": improvements_json(&iters_state.val_improvements)
    })
}

pub fn backtest_results_json(bt_results: &BacktestResults) -> Value {
    let state = &bt_results.final_state;

    json!({
        "is_invalid": bt_results.is_invalid,
        "excess_sharpe": bt_results.excess_sharpe,
        "mean_hold_time": bt_results.mean_hold_time,
        "std_hold_time": bt_results.std_hold_time,
        "entries": state.entries,
        "total_exits": state.total_exits,
        "signal_exits": state.signal_exits,
        "stop_loss_exits": state.stop_loss_exits,
        "take_profit_exits": state.take_profit_exits,
        "max_hold_exits": state.max_hold_exits
    })
}

pub fn fold_results_json(folds: &[FoldResults]) -> Value {

    let n_folds = folds.len();
    let mut fold_results = Vec::<Value>::with_capacity(n_folds);

    for i in 0..n_folds {
        let fold = &folds[i];
        fold_results.push(json!({
            "start_timestamp": fold.start_timestamp,
            "end_timestamp": fold.end_timestamp,
            "opt_results": opt_results_json(&fold.opt_results),
            "train_results": backtest_results_json(&fold.train_results),
            "val_results": backtest_results_json(&fold.val_results),
            "test_results": backtest_results_json(&fold.test_results)
        }));
    }
    Value::Array(fold_results)
}
