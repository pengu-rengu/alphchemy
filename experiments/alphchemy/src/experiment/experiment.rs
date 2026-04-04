use std::collections::{HashMap, HashSet};
use ndarray::Array1;
use serde_json::Value;

use crate::network::network::{Network, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties, parse_logic_net, parse_logic_penalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties, parse_decision_net, parse_decision_penalties};
use crate::features::features::{Feature, FeatTable, feat_ids, feat_table, parse_feats};
use crate::actions::actions::{Action, Actions, construct_net};
use crate::actions::logic_actions::{LogicActions, parse_logic_actions};
use crate::actions::decision_actions::{DecisionActions, parse_decision_actions};
use crate::optimizer::optimizer::{ItersState, StopConds, parse_stop_conds};
use crate::optimizer::genetic::{GeneticOpt, parse_opt};
use crate::utils::{get_field, from_field};

use super::strategy::{Strategy, EntrySchema, ExitSchema, net_signals};
use super::backtest::{BacktestSchema, BacktestResults, backtest, parse_backtest_schema};
use super::tojson::experiment_results_json;

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

    let n_folds = fold_results.len();
    let n_invalid_f64 = n_invalid as f64;
    let n_folds_f64 = n_folds as f64;
    let invalid_frac = if n_folds == 0 { 0.0 } else { n_invalid_f64 / n_folds_f64 };

    ExperimentResults {
        fold_results,
        overall_excess_sharpe,
        invalid_frac
    }
}

pub fn run_experiment<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(experiment: &Experiment<T, P, A>, data: &HashMap<String, Array1<f64>>) -> ExperimentResults {
    let close = data.get("close").unwrap();
    let close_slice = close.as_slice().unwrap();
    let full_feat_table = feat_table(&experiment.strategy.feats, data);
    let folds = get_folds(experiment, close_slice, &full_feat_table);

    let fold_results: Vec<FoldResults> = folds.iter()
        .map(|fold| fold.run_fold(experiment))
        .collect();

    experiment_results(fold_results)
}


pub enum ExperimentVariant {
    Logic(Experiment<LogicNet, LogicPenalties, LogicActions>),
    Decision(Experiment<DecisionNet, DecisionPenalties, DecisionActions>)
}

fn validate_schema_id(ids: &mut HashSet<String>, schema_id: &str, field: &str, idx: usize, schema_type: &str) -> Result<(), String> {
    if schema_id.is_empty() {
        return Err(format!("{field}[{idx}]: id must not be empty"));
    }

    let schema_id_string = schema_id.to_string();
    if !ids.insert(schema_id_string) {
        return Err(format!("duplicate {schema_type} schema id: {schema_id}"));
    }

    Ok(())
}

fn parse_entry_schemas(json: &Value) -> Result<Vec<EntrySchema>, String> {
    let entry_schemas = from_field::<Vec<EntrySchema>>(json, "entry_schemas")?;
    let mut ids = HashSet::new();

    for (idx, entry_schema) in entry_schemas.iter().enumerate() {
        validate_schema_id(&mut ids, &entry_schema.id, "entry_schemas", idx, "entry")?;
    }

    Ok(entry_schemas)
}

fn parse_exit_schemas(json: &Value) -> Result<Vec<ExitSchema>, String> {
    let exit_schemas = from_field::<Vec<ExitSchema>>(json, "exit_schemas")?;
    let mut ids = HashSet::new();

    for (idx, exit_schema) in exit_schemas.iter().enumerate() {
        validate_schema_id(&mut ids, &exit_schema.id, "exit_schemas", idx, "exit")?;
    }

    Ok(exit_schemas)
}

fn validate_schemas(global_max_positions: usize, entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema]) -> Result<(), String> {
    if entry_schemas.is_empty() {
        return Err("entry_schemas must not be empty".to_string());
    }
    if exit_schemas.is_empty() {
        return Err("exit_schemas must not be empty".to_string());
    }
    if global_max_positions == 0 {
        return Err("global_max_positions must be > 0".to_string());
    }

    for (i, entry_schema) in entry_schemas.iter().enumerate() {
        let too_small = entry_schema.position_size <= 0.0;
        let too_large = entry_schema.position_size > 1.0;
        if too_small || too_large {
            return Err(format!("entry_schemas[{i}]: position_size must be > 0.0 and <= 1.0"));
        }
        if entry_schema.max_positions <= 0 {
            return Err(format!("entry_schemas[{i}]: max_positions must be > 0"));
        }
    }

    let mut entry_ids = HashSet::with_capacity(entry_schemas.len());
    for entry_schema in entry_schemas {
        let entry_id = entry_schema.id.as_str();
        entry_ids.insert(entry_id);
    }

    for (i, exit_schema) in exit_schemas.iter().enumerate() {

        if exit_schema.stop_loss <= 0.0 {
            return Err(format!("exit_schemas[{i}]: stop_loss must be > 0.0"));
        }
        if exit_schema.take_profit <= 0.0 {
            return Err(format!("exit_schemas[{i}]: take_profit must be > 0.0"));
        }
        if exit_schema.max_hold_time == 0 {
            return Err(format!("exit_schemas[{i}]: max_hold_time must be > 0"));
        }
        if exit_schema.entry_ids.is_empty() {
            return Err(format!("exit_schemas[{i}]: entry_ids must not be empty"));
        }

        for entry_id in &exit_schema.entry_ids {
            let entry_id_str = entry_id.as_str();
            let is_known = entry_ids.contains(entry_id_str);
            if !is_known {
                return Err(format!("exit_schemas[{i}]: unknown entry_id: {entry_id}"));
            }
        }
    }

    Ok(())
}

struct StrategyData {
    feats: Vec<Box<dyn Feature>>,
    feat_ids: Vec<String>,
    stop_conds: StopConds,
    opt: GeneticOpt,
    global_max_positions: usize,
    entry_schemas: Vec<EntrySchema>,
    exit_schemas: Vec<ExitSchema>
}

fn parse_strategy_data(json: &Value) -> Result<StrategyData, String> {
    let maybe_feats_json = json.get("feats");
    let maybe_feats_array = maybe_feats_json.and_then(|value| value.as_array());
    let feats_array = maybe_feats_array.ok_or_else(|| "missing or invalid feats array".to_string())?;

    let feats = parse_feats(feats_array)?;
    let feat_ids = feat_ids(&feats);
    let stop_conds_json = get_field(json, "stop_conds")?;
    let stop_conds = parse_stop_conds(stop_conds_json)?;
    let opt_json = get_field(json, "opt")?;
    let opt = parse_opt(opt_json)?;
    let global_max_positions = from_field::<usize>(json, "global_max_positions")?;
    let entry_schemas = parse_entry_schemas(json)?;
    let exit_schemas = parse_exit_schemas(json)?;
    validate_schemas(global_max_positions, &entry_schemas, &exit_schemas)?;
    Ok(StrategyData { feats, feat_ids, stop_conds, opt, global_max_positions, entry_schemas, exit_schemas })
}

pub fn parse_logic_strategy(json: &Value) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let sj = parse_strategy_data(json)?;
    let base_net_json = get_field(json, "base_net")?;
    let base_net = parse_logic_net(base_net_json, &sj.feat_ids)?;

    let actions_json = get_field(json, "actions")?;
    let actions = parse_logic_actions(actions_json, &sj.feats)?;

    let penalties_json = get_field(json, "penalties")?;
    let penalties = parse_logic_penalties(penalties_json)?;
    Ok(Strategy {
        base_net,
        feats: sj.feats,
        actions,
        penalties,
        stop_conds: sj.stop_conds,
        opt: sj.opt,
        global_max_positions: sj.global_max_positions,
        entry_schemas: sj.entry_schemas,
        exit_schemas: sj.exit_schemas
    })
}

pub fn parse_decision_strategy(json: &Value) -> Result<Strategy<DecisionNet, DecisionPenalties, DecisionActions>, String> {
    let sj = parse_strategy_data(json)?;
    let base_net_json = get_field(json, "base_net")?;
    let base_net = parse_decision_net(base_net_json, &sj.feat_ids)?;

    let actions_json = get_field(json, "actions")?;
    let actions = parse_decision_actions(actions_json, &sj.feats)?;

    let penalties_json = get_field(json, "penalties")?;
    let penalties = parse_decision_penalties(penalties_json)?;
    Ok(Strategy {
        base_net,
        feats: sj.feats,
        actions,
        penalties,
        stop_conds: sj.stop_conds,
        opt: sj.opt,
        global_max_positions: sj.global_max_positions,
        entry_schemas: sj.entry_schemas,
        exit_schemas: sj.exit_schemas
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

pub fn run_experiment_json(json: &Value, data: &HashMap<String, Array1<f64>>) -> Value {
    let parse_result = parse_experiment(json);

    let experiment = match parse_result {
        Ok(exp) => exp,
        Err(err) => {
            println!("{}", err);
            return serde_json::json!({
                "error": err,
                "is_internal": false
            });
        }
    };

    let results = match &experiment {
        ExperimentVariant::Logic(exp) => run_experiment(exp, data),
        ExperimentVariant::Decision(exp) => run_experiment(exp, data)
    };

    experiment_results_json(&results)
}
