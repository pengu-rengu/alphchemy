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

fn sample_equity(equity: &[f64]) -> Vec<f64> {
    let len = equity.len();
    if len <= 100 {
        return equity.to_vec();
    }

    let span = len - 1;
    let mut sampled = Vec::with_capacity(100);
    for i in 0..100 {
        let scaled = i * span;
        let idx = scaled / 99;
        sampled.push(equity[idx]);
    }
    sampled
}

pub fn backtest_results_json(bt_results: &BacktestResults) -> Value {
    json!({
        "is_invalid": bt_results.is_invalid,
        "metrics": bt_results.metrics,
        "equity_curve": sample_equity(&bt_results.final_state.equity)
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
            "train_start_timestamp": fold.train_start_timestamp,
            "train_end_timestamp": fold.train_end_timestamp,
            "val_start_timestamp": fold.val_start_timestamp,
            "val_end_timestamp": fold.val_end_timestamp,
            "test_start_timestamp": fold.test_start_timestamp,
            "test_end_timestamp": fold.test_end_timestamp,
            "opt_results": opt_results_json(&fold.opt_results),
            "train_results": backtest_results_json(&fold.train_results),
            "val_results": backtest_results_json(&fold.val_results),
            "test_results": backtest_results_json(&fold.test_results)
        }));
    }
    Value::Array(fold_results)
}
