use std::collections::HashMap;
use std::panic;
use serde_json::{Value, json};

use crate::network::network::{Network, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties};
use crate::features::features::FeatTable;
use crate::features::features::feat_table;
use crate::actions::actions::{Action, Actions, construct_net};
use crate::actions::logic_actions::LogicActions;
use crate::actions::decision_actions::DecisionActions;
use crate::optimizer::optimizer::ItersState;
use crate::utils::{get_field, from_field};

use super::strategy::{Strategy, net_signals};
use super::backtest::{BacktestSchema, BacktestResults, backtest, parse_backtest_schema};
use super::tojson::fold_results_json;

pub use super::strategy::{parse_logic_strategy, parse_decision_strategy};

#[derive(Clone, Debug)]
pub struct FoldResults {
    pub start_idx: usize,
    pub end_idx: usize,
    pub train_results: BacktestResults,
    pub val_results: BacktestResults,
    pub test_results: BacktestResults,
    pub opt_results: ItersState
}

#[derive(Clone, Copy, Debug)]
pub struct DataRange {
    pub start_idx: usize,
    pub end_idx: usize
}

pub struct Experiment<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub val_size: f64,
    pub test_size: f64,
    pub cv_folds: usize,
    pub fold_size: f64,
    pub backtest_schema: BacktestSchema,
    pub strategy: Strategy<T, P, A>
}


fn run_backtest<T: Network + Clone, A: Actions<T>>(
    net: &mut T,
    strategy: &Strategy<T, impl Penalties<T>, A>,
    schema: &BacktestSchema,
    feat_table: &FeatTable,
    data_range: DataRange,
    close_prices: &[f64]
) -> BacktestResults {
    let signals = net_signals(
        net,
        &strategy.entry_schemas,
        &strategy.exit_schemas,
        feat_table,
        data_range.start_idx,
        data_range.end_idx,
        schema.delay
    );

    backtest(
        signals,
        &strategy.entry_schemas,
        &strategy.exit_schemas,
        strategy.global_max_positions,
        schema,
        close_prices
    )
}

fn criterion<'a, T: Network + Clone + 'a, P: Penalties<T> + 'a, A: Actions<T> + 'a>(strategy: &'a Strategy<T, P, A>, schema: &'a BacktestSchema, feat_table: &'a FeatTable, data_range: DataRange, close_prices: &'a [f64]) -> impl Fn(&[Action]) -> f64 + 'a {
    move |seq: &[Action]| {
        let mut net = construct_net(&strategy.base_net, seq, &strategy.actions);

        let signals = net_signals(
            &mut net,
            &strategy.entry_schemas,
            &strategy.exit_schemas,
            feat_table,
            data_range.start_idx,
            data_range.end_idx,
            schema.delay
        );

        let excess_sharpe = backtest(signals, &strategy.entry_schemas, &strategy.exit_schemas, strategy.global_max_positions, schema, close_prices).excess_sharpe;

        let n_feats = strategy.feats.len();
        let penalty_score = strategy.penalties.penalty(&net, n_feats);

        excess_sharpe - penalty_score
    }
}


pub struct FoldData<'a> {
    pub train_close: &'a [f64],
    pub val_close: &'a [f64],
    pub test_close: &'a [f64],
    pub feat_table: &'a FeatTable,
    pub train_range: DataRange,
    pub val_range: DataRange,
    pub test_range: DataRange,
    pub start_idx: usize,
    pub end_idx: usize
}

impl FoldData<'_> {
    pub fn run_opt<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(&self, strategy: &Strategy<T, P, A>, schema: &BacktestSchema) -> ItersState {
        let actions_list = strategy.actions.actions_list();

        let train_criterion = criterion(strategy, schema, self.feat_table, self.train_range, self.train_close);
        let val_criterion = criterion(
            strategy, schema,
            self.feat_table, self.val_range, self.val_close
        );

        strategy.opt.run_genetic(&strategy.stop_conds, &actions_list, &train_criterion, &val_criterion)
    }

    pub fn run_fold<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(&self, experiment: &Experiment<T, P, A>) -> FoldResults {
        let strategy = &experiment.strategy;
        let schema = &experiment.backtest_schema;

        let opt_results = self.run_opt(strategy, schema);
        let mut net = construct_net(&strategy.base_net, &opt_results.best_seq, &strategy.actions);

        let train_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.train_range, self.train_close);
        let val_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.val_range, self.val_close);
        let test_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.test_range, self.test_close);

        FoldResults {
            start_idx: self.start_idx,
            end_idx: self.end_idx,
            train_results,
            val_results,
            test_results,
            opt_results
        }
    }
}

pub fn get_folds<'a, T: Network, P: Penalties<T>, A: Actions<T>>(experiment: &Experiment<T, P, A>, close: &'a [f64], feat_table: &'a FeatTable) -> Vec<FoldData<'a>> {
    let cv_folds = experiment.cv_folds;
    let data_len = close.len();

    let data_len_f64 = data_len as f64;
    let fold_len = (data_len_f64 * experiment.fold_size) as usize;
    let fold_len_f64 = fold_len as f64;

    let range = data_len - fold_len;
    let divisor = if cv_folds > 1 {
        cv_folds - 1
    } else {
        1
    };
    let stride = range / divisor;

    let test_frac = 1.0 - experiment.test_size;
    let test_offset = (test_frac * fold_len_f64) as usize;

    let val_frac = test_frac - experiment.val_size;
    let val_offset = (val_frac * fold_len_f64) as usize;

    let mut folds = Vec::with_capacity(cv_folds);

    for i in 0..cv_folds {
        let start_idx = i * stride;
        let val_split = start_idx + val_offset;
        let test_split = start_idx + test_offset;
        let end_idx = start_idx + fold_len - 1;
        let train_range = DataRange {
            start_idx,
            end_idx: val_split
        };
        let val_range = DataRange {
            start_idx: val_split + 1,
            end_idx: test_split
        };
        let test_range = DataRange {
            start_idx: test_split + 1,
            end_idx
        };

        let fold = FoldData {
            train_close: &close[start_idx..=val_split],
            val_close: &close[val_split + 1..=test_split],
            test_close: &close[test_split + 1..=end_idx],
            feat_table,
            train_range,
            val_range,
            test_range,
            start_idx,
            end_idx
        };
        folds.push(fold);
    }

    folds
}

pub fn run_experiment<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(experiment: &Experiment<T, P, A>, data: &HashMap<String, Vec<f64>>) -> Vec<FoldResults> {
    let close = data.get("close").unwrap();
    let close_slice = close.as_slice();
    let full_feat_table = feat_table(&experiment.strategy.feats, data);
    let folds = get_folds(experiment, close_slice, &full_feat_table);
    
    folds.iter()
        .map(|fold| fold.run_fold(experiment))
        .collect()
}


pub enum ExperimentVariant {
    Logic(Experiment<LogicNet, LogicPenalties, LogicActions>),
    Decision(Experiment<DecisionNet, DecisionPenalties, DecisionActions>)
}

pub fn parse_experiment(json: &Value) -> Result<ExperimentVariant, String> {
    let val_size: f64 = from_field(json, "val_size")?;
    let test_size: f64 = from_field(json, "test_size")?;
    let cv_folds: usize = from_field(json, "cv_folds")?;
    let fold_size: f64 = from_field(json, "fold_size")?;

    if val_size <= 0.0 { return Err("val_size must be > 0.0".to_string()); }
    if test_size <= 0.0 { return Err("test_size must be > 0.0".to_string()); }
    if val_size + test_size >= 1.0 { return Err("val_size + test_size must be < 1.0".to_string()); }
    if cv_folds == 0 { return Err("cv_folds must be > 0".to_string()); }
    
    let fold_too_small = fold_size <= 0.0;
    let fold_too_large = fold_size > 1.0;
    if fold_too_small || fold_too_large { return Err("fold_size must be > 0.0 and <= 1.0".to_string()); }

    let backtest_json = get_field(json, "backtest_schema")?;
    let backtest_schema = parse_backtest_schema(backtest_json)?;

    let strategy_json = get_field(json, "strategy")?;
    let base_net_json = strategy_json.get("base_net");
    let type_json = base_net_json.and_then(|value| value.get("type"));
    let maybe_type = type_json.and_then(|value| value.as_str());
    let net_type = maybe_type.ok_or_else(|| "missing or invalid base_net type".to_string())?;

    match net_type {
        "logic" => {
            let strategy = parse_logic_strategy(strategy_json)?;
            let experiment = Experiment {
                val_size,
                test_size,
                cv_folds,
                fold_size,
                backtest_schema,
                strategy
            };
            let variant = ExperimentVariant::Logic(experiment);
            Ok(variant)
        }
        "decision" => {
            let strategy = parse_decision_strategy(strategy_json)?;
            let experiment = Experiment {
                val_size,
                test_size,
                cv_folds,
                fold_size,
                backtest_schema,
                strategy
            };
            let variant = ExperimentVariant::Decision(experiment);
            Ok(variant)
        }
        _ => Err(format!("invalid network type: {net_type}"))
    }
}

pub fn run_experiment_json(json: &Value, data: &HashMap<String, Vec<f64>>) -> Value {
    let parse_result = parse_experiment(json);

    let experiment = match parse_result {
        Ok(exp) => exp,
        Err(error) => {
            println!("{}", error);
            return json!({
                "error": error,
                "is_internal": false
            });
        }
    };

    let run_result = panic::catch_unwind(
        || match &experiment {
            ExperimentVariant::Logic(variant) => run_experiment(variant, data),
            ExperimentVariant::Decision(variant) => run_experiment(variant, data)
        }
    );

    match run_result {
        Ok(results) => fold_results_json(&results),
        Err(error) => {
            let error_msg = match error.downcast_ref::<&str>() {
                Some(msg) => msg,
                None => "an internal error has occurred"
            };
            json!({
                "error": error_msg,
                "is_internal": true
            })
        }
    }
}
