use std::collections::HashMap;
use ndarray::{Array1, Array2};
use serde_json::Value;

use crate::network::network::{Network, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties, parse_logic_net, parse_logic_penalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties, parse_decision_net, parse_decision_penalties};
use crate::features::features::{Feature, feat_matrix, parse_feat, validate_feat_ids};
use crate::actions::actions::{Action, Actions, construct_net};
use crate::actions::logic_actions::{LogicActions, parse_logic_actions};
use crate::actions::decision_actions::{DecisionActions, parse_decision_actions};
use crate::optimizer::optimizer::{ItersState, parse_stop_conds};
use crate::optimizer::genetic::parse_opt;
use crate::utils::{get_field, from_field};

use super::strategy::{Strategy, EntrySchema, ExitSchema, net_signals};
use super::backtest::{BacktestSchema, BacktestResults, backtest, parse_backtest_schema};

#[derive(Clone, Debug)]
pub struct FoldResults {
    pub start_idx: usize,
    pub end_idx: usize,
    pub train_results: BacktestResults,
    pub val_results: BacktestResults,
    pub test_results: BacktestResults,
    pub opt_results: ItersState
}

#[derive(Clone, Debug)]
pub struct ExperimentResults {
    pub fold_results: Vec<FoldResults>,
    pub overall_excess_sharpe: f64,
    pub invalid_frac: f64
}

pub struct Experiment<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub val_size: f64,
    pub test_size: f64,
    pub cv_folds: usize,
    pub fold_size: f64,
    pub backtest_schema: BacktestSchema,
    pub strategy: Strategy<T, P, A>
}

pub struct FoldData {
    pub train_close: Vec<f64>,
    pub val_close: Vec<f64>,
    pub test_close: Vec<f64>,
    pub train_feat_matrix: Array2<f64>,
    pub val_feat_matrix: Array2<f64>,
    pub test_feat_matrix: Array2<f64>,
    pub start_idx: usize,
    pub end_idx: usize
}

fn run_backtest<T: Network + Clone, A: Actions<T>>(
    net: &mut T,
    strategy: &Strategy<T, impl Penalties<T>, A>,
    schema: &BacktestSchema,
    feat_matrix: &Array2<f64>,
    close_prices: &[f64]
) -> BacktestResults {
    let signals = net_signals(
        net,
        &strategy.entry_schemas,
        &strategy.exit_schemas,
        feat_matrix,
        schema.delay
    );

    backtest(
        signals,
        &strategy.entry_schemas,
        &strategy.exit_schemas,
        schema,
        close_prices
    )
}

fn criterion<'a, T: Network + Clone + 'a, P: Penalties<T> + 'a, A: Actions<T> + 'a>(
    strategy: &'a Strategy<T, P, A>,
    schema: &'a BacktestSchema,
    feat_matrix: &'a Array2<f64>,
    close_prices: &'a [f64]
) -> impl Fn(&[Action]) -> f64 + 'a {
    move |seq: &[Action]| {
        let mut net = construct_net(&strategy.base_net, seq, &strategy.actions);

        let signals = net_signals(
            &mut net,
            &strategy.entry_schemas,
            &strategy.exit_schemas,
            feat_matrix,
            schema.delay
        );

        let excess_sharpe = backtest(
            signals,
            &strategy.entry_schemas,
            &strategy.exit_schemas,
            schema,
            close_prices
        ).excess_sharpe;

        let n_feats = strategy.feats.len();
        let penalty_score = strategy.penalties.penalty(&net, n_feats);

        excess_sharpe - penalty_score
    }
}

fn run_opt<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(
    strategy: &Strategy<T, P, A>,
    schema: &BacktestSchema,
    fold: &FoldData
) -> ItersState {
    let actions_list = strategy.actions.actions_list();

    let train_criterion = criterion(
        strategy, schema,
        &fold.train_feat_matrix, &fold.train_close
    );
    let val_criterion = criterion(
        strategy, schema,
        &fold.val_feat_matrix, &fold.val_close
    );

    strategy.opt.run_genetic(
        &strategy.stop_conds,
        &actions_list,
        &train_criterion,
        &val_criterion
    )
}

fn run_fold<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(
    experiment: &Experiment<T, P, A>,
    fold: &FoldData
) -> FoldResults {
    let strategy = &experiment.strategy;
    let schema = &experiment.backtest_schema;

    let opt_results = run_opt(strategy, schema, fold);
    let mut net = construct_net(&strategy.base_net, &opt_results.best_seq, &strategy.actions);

    let train_results = run_backtest(&mut net, strategy, schema, &fold.train_feat_matrix, &fold.train_close);
    let val_results = run_backtest(&mut net, strategy, schema, &fold.val_feat_matrix, &fold.val_close);
    let test_results = run_backtest(&mut net, strategy, schema, &fold.test_feat_matrix, &fold.test_close);

    FoldResults {
        start_idx: fold.start_idx,
        end_idx: fold.end_idx,
        train_results,
        val_results,
        test_results,
        opt_results
    }
}

fn fold_from_indices(
    close_prices: &[f64],
    ohlc_data: &HashMap<String, Array1<f64>>,
    feats: &[Box<dyn Feature>],
    start_idx: usize,
    val_split: usize,
    test_split: usize,
    end_idx: usize
) -> FoldData {
    let slice_ohlc = |from: usize, to: usize| -> HashMap<String, Array1<f64>> {
        ohlc_data.iter()
            .map(|(k, v)| (k.clone(), v.slice(ndarray::s![from..=to]).to_owned()))
            .collect()
    };

    let train_ohlc = slice_ohlc(start_idx, val_split);
    let val_ohlc = slice_ohlc(val_split + 1, test_split);
    let test_ohlc = slice_ohlc(test_split + 1, end_idx);

    let train_matrix = feat_matrix(feats, &train_ohlc);
    let val_matrix = feat_matrix(feats, &val_ohlc);
    let test_matrix = feat_matrix(feats, &test_ohlc);

    let train_close = close_prices[start_idx..=val_split].to_vec();
    let val_close = close_prices[val_split + 1..=test_split].to_vec();
    let test_close = close_prices[test_split + 1..=end_idx].to_vec();

    FoldData {
        train_close,
        val_close,
        test_close,
        train_feat_matrix: train_matrix,
        val_feat_matrix: val_matrix,
        test_feat_matrix: test_matrix,
        start_idx,
        end_idx
    }
}

pub fn get_folds<T: Network, P: Penalties<T>, A: Actions<T>>(
    experiment: &Experiment<T, P, A>,
    close_prices: &[f64],
    ohlc_data: &HashMap<String, Array1<f64>>
) -> Vec<FoldData> {
    let strategy = &experiment.strategy;
    let cv_folds = experiment.cv_folds;
    let data_len = close_prices.len();

    let fold_len = (data_len as f64 * experiment.fold_size) as usize;

    let range = data_len - fold_len;
    let divisor = if cv_folds > 1 { cv_folds - 1 } else { 1 };
    let stride = range / divisor;

    let test_frac = 1.0 - experiment.test_size;
    let test_offset = (test_frac * fold_len as f64) as usize;

    let val_frac = test_frac - experiment.val_size;
    let val_offset = (val_frac * fold_len as f64) as usize;

    let mut folds = Vec::with_capacity(cv_folds);

    for i in 0..cv_folds {
        let start_idx = i * stride;
        let val_split = start_idx + val_offset;
        let test_split = start_idx + test_offset;
        let end_idx = start_idx + fold_len - 1;

        folds.push(fold_from_indices(
            close_prices, ohlc_data, &strategy.feats,
            start_idx, val_split, test_split, end_idx
        ));
    }

    folds
}

pub fn experiment_results(fold_results: Vec<FoldResults>) -> ExperimentResults {
    let mut excess_sharpes = Vec::new();
    let mut n_invalid = 0;

    for fr in &fold_results {
        if fr.test_results.is_invalid {
            n_invalid += 1;
        } else {
            excess_sharpes.push(fr.test_results.excess_sharpe);
        }
    }

    let overall_excess_sharpe = if excess_sharpes.is_empty() {
        0.0
    } else {
        excess_sharpes.iter().sum::<f64>() / excess_sharpes.len() as f64
    };

    let n_folds = fold_results.len() as f64;
    let invalid_frac = n_invalid as f64 / n_folds;

    ExperimentResults {
        fold_results,
        overall_excess_sharpe,
        invalid_frac
    }
}

pub fn run_experiment<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(
    experiment: &Experiment<T, P, A>,
    close_prices: &[f64],
    ohlc_data: &HashMap<String, Array1<f64>>
) -> ExperimentResults {
    let folds = get_folds(experiment, close_prices, ohlc_data);

    let fold_results: Vec<FoldResults> = folds.iter()
        .map(|fold| run_fold(experiment, fold))
        .collect();

    experiment_results(fold_results)
}


pub enum ExperimentVariant {
    Logic(Experiment<LogicNet, LogicPenalties, LogicActions>),
    Decision(Experiment<DecisionNet, DecisionPenalties, DecisionActions>)
}


fn validate_schemas(entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema]) -> Result<(), String> {
    if entry_schemas.is_empty() {
        return Err("entry_schemas must not be empty".to_string());
    }
    if exit_schemas.is_empty() {
        return Err("exit_schemas must not be empty".to_string());
    }

    for (i, es) in entry_schemas.iter().enumerate() {
        if es.position_size <= 0.0 || es.position_size > 1.0 {
            return Err(format!("entry_schemas[{i}]: position_size must be > 0.0 and <= 1.0"));
        }
        if es.max_positions <= 0 {
            return Err(format!("entry_schemas[{i}]: max_positions must be > 0"));
        }
    }

    for (i, xs) in exit_schemas.iter().enumerate() {
        if xs.stop_loss <= 0.0 {
            return Err(format!("exit_schemas[{i}]: stop_loss must be > 0.0"));
        }
        if xs.take_profit <= 0.0 {
            return Err(format!("exit_schemas[{i}]: take_profit must be > 0.0"));
        }
        if xs.max_hold_time == 0 {
            return Err(format!("exit_schemas[{i}]: max_hold_time must be > 0"));
        }
        if xs.entry_indices.is_empty() {
            return Err(format!("exit_schemas[{i}]: entry_idxs must not be empty"));
        }
        for &idx in &xs.entry_indices {
            if idx >= entry_schemas.len() {
                return Err(format!("exit_schemas[{i}]: entry_idxs contains index {idx} >= entry_schemas length"));
            }
        }
    }

    Ok(())
}

pub fn parse_logic_strategy(json: &Value) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let feats_json = json.get("feats").and_then(|v| v.as_array())
        .ok_or_else(|| "missing or invalid feats array".to_string())?;
    let feats = feats_json.iter()
        .map(|feat_json| parse_feat(feat_json))
        .collect::<Result<Vec<_>, _>>()?;
    let n_feats = feats.len();

    validate_feat_ids(&feats)?;

    let base_net = parse_logic_net(get_field(json, "base_net")?, n_feats)?;
    let actions = parse_logic_actions(get_field(json, "actions")?, &feats)?;
    let penalties = parse_logic_penalties(get_field(json, "penalties")?)?;
    let stop_conds = parse_stop_conds(get_field(json, "stop_conds")?)?;
    let opt = parse_opt(get_field(json, "opt")?)?;

    let entry_schemas: Vec<EntrySchema> = from_field(json, "entry_schemas")?;
    let exit_schemas: Vec<ExitSchema> = from_field(json, "exit_schemas")?;
    validate_schemas(&entry_schemas, &exit_schemas)?;

    Ok(Strategy {
        base_net,
        feats,
        actions,
        penalties,
        stop_conds,
        opt,
        entry_schemas,
        exit_schemas
    })
}

pub fn parse_decision_strategy(json: &Value) -> Result<Strategy<DecisionNet, DecisionPenalties, DecisionActions>, String> {
    let feats_json = json.get("feats").and_then(|v| v.as_array())
        .ok_or_else(|| "missing or invalid feats array".to_string())?;
    let feats: Vec<Box<dyn Feature>> = feats_json.iter()
        .map(|fj| parse_feat(fj))
        .collect::<Result<Vec<_>, _>>()?;
    let n_feats = feats.len();

    validate_feat_ids(&feats)?;

    let base_net = parse_decision_net(get_field(json, "base_net")?, n_feats)?;
    let actions = parse_decision_actions(get_field(json, "actions")?, &feats)?;
    let penalties = parse_decision_penalties(get_field(json, "penalties")?)?;
    let stop_conds = parse_stop_conds(get_field(json, "stop_conds")?)?;
    let opt = parse_opt(get_field(json, "opt")?)?;

    let entry_schemas: Vec<EntrySchema> = from_field(json, "entry_schemas")?;
    let exit_schemas: Vec<ExitSchema> = from_field(json, "exit_schemas")?;
    validate_schemas(&entry_schemas, &exit_schemas)?;

    Ok(Strategy {
        base_net,
        feats,
        actions,
        penalties,
        stop_conds,
        opt,
        entry_schemas,
        exit_schemas
    })
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
    if fold_size <= 0.0 || fold_size > 1.0 { return Err("fold_size must be > 0.0 and <= 1.0".to_string()); }

    let backtest_schema = parse_backtest_schema(get_field(json, "backtest_schema")?)?;

    let strategy_json = get_field(json, "strategy")?;
    let net_type = strategy_json.get("base_net")
        .and_then(|v| v.get("type"))
        .and_then(|v| v.as_str())
        .ok_or_else(|| "missing or invalid base_net type".to_string())?;

    match net_type {
        "logic" => {
            let strategy = parse_logic_strategy(strategy_json)?;
            Ok(ExperimentVariant::Logic(Experiment {
                val_size,
                test_size,
                cv_folds,
                fold_size,
                backtest_schema,
                strategy
            }))
        }
        "decision" => {
            let strategy = parse_decision_strategy(strategy_json)?;
            Ok(ExperimentVariant::Decision(Experiment {
                val_size,
                test_size,
                cv_folds,
                fold_size,
                backtest_schema,
                strategy
            }))
        }
        _ => Err(format!("invalid network type: {net_type}"))
    }
}
