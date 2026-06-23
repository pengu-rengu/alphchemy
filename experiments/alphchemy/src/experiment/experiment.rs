use serde_json::{Value, json};

use crate::fetch_data::fetch_btc_ohlc;
use crate::network::network::{Network, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties};
use crate::features::features::TimestampedTable;
use crate::features::features::feat_table;
use crate::actions::actions::{Action, Actions, construct_net};
use crate::actions::logic_actions::LogicActions;
use crate::actions::decision_actions::DecisionActions;
use crate::optimizer::optimizer::ItersState;
use crate::utils::{get_field, field_f64, field_usize, field_str};

use super::strategy::{Strategy, net_signals};
use super::backtest::{BacktestSchema, BacktestResults, backtest, parse_backtest_schema};
use super::tojson::fold_results_json;

pub use super::strategy::{parse_logic_strategy, parse_decision_strategy};

#[derive(Clone, Debug)]
pub struct FoldResults {
    pub start_timestamp: String,
    pub end_timestamp: String,
    pub train_start_timestamp: String,
    pub train_end_timestamp: String,
    pub val_start_timestamp: String,
    pub val_end_timestamp: String,
    pub test_start_timestamp: String,
    pub test_end_timestamp: String,
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
    pub start_timestamp: String,
    pub end_timestamp: String,
    pub backtest_schema: BacktestSchema,
    pub strategy: Strategy<T, P, A>
}


fn run_backtest<T: Network + Clone, A: Actions<T>>(net: &mut T, strategy: &Strategy<T, impl Penalties<T>, A>, schema: &BacktestSchema, feat_table: &TimestampedTable, data_range: DataRange, close_prices: &[f64]) -> BacktestResults {
    let signals = net_signals(net, &strategy.entry_ptr, &strategy.exit_ptr, feat_table, data_range.start_idx, data_range.end_idx, schema.delay);

    backtest(
        signals,
        strategy.qty,
        strategy.stop_loss,
        strategy.take_profit,
        strategy.max_hold_time,
        schema,
        close_prices
    )
}

fn criterion<'a, T: Network + Clone + 'a, P: Penalties<T> + 'a, A: Actions<T> + 'a>(strategy: &'a Strategy<T, P, A>, schema: &'a BacktestSchema, feat_table: &'a TimestampedTable, data_range: DataRange, close_prices: &'a [f64]) -> impl Fn(&[Action]) -> f64 + 'a {
    move |seq: &[Action]| {
        let mut net = construct_net(&strategy.base_net, seq, &strategy.actions);

        let signals = net_signals(
            &mut net,
            &strategy.entry_ptr,
            &strategy.exit_ptr,
            feat_table,
            data_range.start_idx,
            data_range.end_idx,
            schema.delay
        );

        let excess_sharpe = backtest(signals, strategy.qty, strategy.stop_loss, strategy.take_profit, strategy.max_hold_time, schema, close_prices).excess_sharpe;

        let n_feats = strategy.feats.len();
        let penalty_score = strategy.penalties.penalty(&net, n_feats);

        excess_sharpe - penalty_score
    }
}


pub struct FoldData<'a> {
    pub train_close: &'a [f64],
    pub val_close: &'a [f64],
    pub test_close: &'a [f64],
    pub feat_table: &'a TimestampedTable,
    pub train_range: DataRange,
    pub val_range: DataRange,
    pub test_range: DataRange,
    pub start_timestamp: String,
    pub end_timestamp: String,
    pub train_start_timestamp: String,
    pub train_end_timestamp: String,
    pub val_start_timestamp: String,
    pub val_end_timestamp: String,
    pub test_start_timestamp: String,
    pub test_end_timestamp: String
}

impl FoldData<'_> {
    pub fn run_opt<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(&self, strategy: &Strategy<T, P, A>, schema: &BacktestSchema) -> ItersState {

        let train_criterion = criterion(strategy, schema, self.feat_table, self.train_range, self.train_close);
        let val_criterion = criterion(
            strategy, schema,
            self.feat_table, self.val_range, self.val_close
        );

        strategy.opt.run_genetic(&strategy.stop_conds, &strategy.actions.actions_list(), &train_criterion, &val_criterion)
    }

    pub fn run_fold<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(&self, experiment: &Experiment<T, P, A>) -> FoldResults {
        let strategy = &experiment.strategy;
        let schema = &experiment.backtest_schema;

        let opt_results = self.run_opt(strategy, schema);
        let mut net = construct_net(&strategy.base_net, &opt_results.best_val_seq, &strategy.actions);

        let train_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.train_range, self.train_close);
        let val_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.val_range, self.val_close);
        let test_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.test_range, self.test_close);

        FoldResults {
            start_timestamp: self.start_timestamp.clone(),
            end_timestamp: self.end_timestamp.clone(),
            train_start_timestamp: self.train_start_timestamp.clone(),
            train_end_timestamp: self.train_end_timestamp.clone(),
            val_start_timestamp: self.val_start_timestamp.clone(),
            val_end_timestamp: self.val_end_timestamp.clone(),
            test_start_timestamp: self.test_start_timestamp.clone(),
            test_end_timestamp: self.test_end_timestamp.clone(),
            train_results,
            val_results,
            test_results,
            opt_results
        }
    }
}

pub fn get_folds<'a, T: Network, P: Penalties<T>, A: Actions<T>>(experiment: &Experiment<T, P, A>, close: &'a [f64], feat_table: &'a TimestampedTable) -> Vec<FoldData<'a>> {
    let timestamps = &feat_table.timestamps;
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

        let start_timestamp = timestamps[start_idx].clone();
        let end_timestamp = timestamps[end_idx].clone();
        let train_start_timestamp = timestamps[start_idx].clone();
        let train_end_timestamp = timestamps[val_split].clone();
        let val_start_timestamp = timestamps[val_split + 1].clone();
        let val_end_timestamp = timestamps[test_split].clone();
        let test_start_timestamp = timestamps[test_split + 1].clone();
        let test_end_timestamp = timestamps[end_idx].clone();
        let fold = FoldData {
            train_close: &close[start_idx..=val_split],
            val_close: &close[val_split + 1..=test_split],
            test_close: &close[test_split + 1..=end_idx],
            feat_table,
            train_range,
            val_range,
            test_range,
            start_timestamp,
            end_timestamp,
            train_start_timestamp,
            train_end_timestamp,
            val_start_timestamp,
            val_end_timestamp,
            test_start_timestamp,
            test_end_timestamp
        };
        folds.push(fold);
    }

    folds
}

pub async fn run_experiment<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(experiment: &Experiment<T, P, A>) -> Result<Vec<FoldResults>, String> {
    let data = fetch_btc_ohlc(&experiment.start_timestamp, &experiment.end_timestamp).await?;
    let close = data.table.get("close").unwrap();
    let feat_values = feat_table(&experiment.strategy.feats, &data);
    let folds = get_folds(experiment, close.as_slice(), &feat_values);

    let results = folds.iter().map(|fold| fold.run_fold(experiment)).collect();

    Ok(results)
}


pub enum ExperimentVariant {
    Logic(Experiment<LogicNet, LogicPenalties, LogicActions>),
    Decision(Experiment<DecisionNet, DecisionPenalties, DecisionActions>)
}

pub fn parse_experiment(json: &Value) -> Result<ExperimentVariant, String> {
    let val_size = field_f64(json, "val_size")?;
    let test_size = field_f64(json, "test_size")?;
    let cv_folds = field_usize(json, "cv_folds")?;
    let fold_size = field_f64(json, "fold_size")?;
    let start_timestamp = field_str(json, "start_timestamp")?.to_string();
    let end_timestamp = field_str(json, "end_timestamp")?.to_string();

    if val_size <= 0.0 { return Err("val_size must be > 0.0".to_string()); }
    if test_size <= 0.0 { return Err("test_size must be > 0.0".to_string()); }
    if val_size + test_size >= 1.0 { return Err("val_size + test_size must be < 1.0".to_string()); }
    if cv_folds == 0 { return Err("cv_folds must be > 0".to_string()); }

    let fold_too_small = fold_size <= 0.0;
    let fold_too_large = fold_size > 1.0;
    if fold_too_small || fold_too_large { return Err("fold_size must be > 0.0 and <= 1.0".to_string()); }

    if start_timestamp >= end_timestamp { return Err("start_timestamp must be < end_timestamp".to_string()); }

    let bt_schema_json = get_field(json, "backtest_schema")?;
    let backtest_schema = parse_backtest_schema(bt_schema_json)?;
    
    let strategy_json = get_field(json, "strategy")?;

    let base_net_json = get_field(strategy_json, "base_net")?;
    let net_type = field_str(base_net_json, "type")?;

    match net_type {
        "logic" => {
            let strategy = parse_logic_strategy(strategy_json)?;
            let experiment = Experiment {
                val_size,
                test_size,
                cv_folds,
                fold_size,
                start_timestamp,
                end_timestamp,
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
                start_timestamp,
                end_timestamp,
                backtest_schema,
                strategy
            };
            let variant = ExperimentVariant::Decision(experiment);
            Ok(variant)
        }
        _ => Err(format!("invalid network type: {net_type}"))
    }
}

pub async fn run_experiment_json(json: &Value) -> Value {
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

    let run_result = match &experiment {
        ExperimentVariant::Logic(variant) => run_experiment(variant).await,
        ExperimentVariant::Decision(variant) => run_experiment(variant).await
    };

    match run_result {
        Ok(results) => fold_results_json(&results),
        Err(error) => json!({
            "error": error,
            "is_internal": false
        })
    }
}
