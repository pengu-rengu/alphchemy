use serde::Serialize;
use serde_json::{Value, json, to_value};

use crate::fetch_data::fetch_ohlc;
use crate::network::network::{Network, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties};
use crate::features::features::TimestampedTable;
use crate::features::features::feat_table;
use crate::actions::actions::{Action, Actions, construct_net};
use crate::actions::logic_actions::LogicActions;
use crate::actions::decision_actions::DecisionActions;
use crate::optimizer::optimizer::ItersState;

use super::strategy::Strategy;
use super::backtest::{BacktestSchema, BacktestResults, backtest};

#[derive(Clone, Debug)]
pub struct FoldResults {
    pub train_start_timestamp: String,
    pub train_end_timestamp: String,
    pub val_start_timestamp: String,
    pub val_end_timestamp: String,
    pub test_start_timestamp: String,
    pub test_end_timestamp: String,
    pub train_results: BacktestResults,
    pub val_results: BacktestResults,
    pub test_results: BacktestResults,
    pub best_train_net: Value,
    pub best_val_net: Value,
    pub opt_results: ItersState
}

#[derive(Clone, Copy, Debug)]
pub struct DataRange {
    pub start_idx: usize,
    pub end_idx: usize
}

struct FoldConfig {
    fold_len: usize,
    stride: usize,
    val_offset: usize,
    test_offset: usize
}

pub struct Experiment<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub val_size: f64,
    pub test_size: f64,
    pub cv_folds: usize,
    pub fold_size: f64,
    pub symbol: String,
    pub start_timestamp: String,
    pub end_timestamp: String,
    pub backtest_schema: BacktestSchema,
    pub strategy: Strategy<T, P, A>
}

impl<T: Network, P: Penalties<T>, A: Actions<T>> Experiment<T, P, A> {
    pub fn to_json(&self) -> Value {
        json!({
            "val_size": self.val_size,
            "test_size": self.test_size,
            "cv_folds": self.cv_folds,
            "fold_size": self.fold_size,
            "symbol": self.symbol,
            "start_timestamp": self.start_timestamp,
            "end_timestamp": self.end_timestamp,
            "backtest_schema": self.backtest_schema,
            "strategy": self.strategy.to_json()
        })
    }
}


fn run_backtest<T: Network + Clone, A: Actions<T>>(net: &mut T, strategy: &Strategy<T, impl Penalties<T>, A>, schema: &BacktestSchema, feat_table: &TimestampedTable, data_range: DataRange, close_prices: &[f64]) -> BacktestResults {
    let signals = strategy.net_signals(net, feat_table, data_range.start_idx, data_range.end_idx, schema.delay);

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

        let signals = strategy.net_signals(
            &mut net,
            feat_table,
            data_range.start_idx,
            data_range.end_idx,
            schema.delay
        );

        let results = backtest(signals, strategy.qty, strategy.stop_loss, strategy.take_profit, strategy.max_hold_time, schema, close_prices);
        let opt_score: f64 = strategy.opt.objectives.iter().map(|objective| objective.weight * results.metrics[&objective.metric]).sum();

        let n_feats = strategy.feats.len();
        let penalty_score = strategy.penalties.penalty(&net, n_feats);

        opt_score - penalty_score
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
    pub train_start_timestamp: String,
    pub train_end_timestamp: String,
    pub val_start_timestamp: String,
    pub val_end_timestamp: String,
    pub test_start_timestamp: String,
    pub test_end_timestamp: String
}

impl<'a> FoldData<'a> {
    fn new(
        close: &'a [f64],
        feat_table: &'a TimestampedTable,
        train_range: DataRange,
        val_range: DataRange,
        test_range: DataRange
    ) -> Self {
        let timestamps = &feat_table.timestamps;

        Self {
            train_close: &close[train_range.start_idx..=train_range.end_idx],
            val_close: &close[val_range.start_idx..=val_range.end_idx],
            test_close: &close[test_range.start_idx..=test_range.end_idx],
            feat_table,
            train_range,
            val_range,
            test_range,
            train_start_timestamp: timestamps[train_range.start_idx].clone(),
            train_end_timestamp: timestamps[train_range.end_idx].clone(),
            val_start_timestamp: timestamps[val_range.start_idx].clone(),
            val_end_timestamp: timestamps[val_range.end_idx].clone(),
            test_start_timestamp: timestamps[test_range.start_idx].clone(),
            test_end_timestamp: timestamps[test_range.end_idx].clone()
        }
    }

    pub fn run_opt<T: Network + Clone, P: Penalties<T>, A: Actions<T>>(&self, strategy: &Strategy<T, P, A>, schema: &BacktestSchema) -> ItersState {

        let train_criterion = criterion(strategy, schema, self.feat_table, self.train_range, self.train_close);
        let val_criterion = criterion(
            strategy, schema,
            self.feat_table, self.val_range, self.val_close
        );

        strategy.opt.run_genetic(&strategy.stop_conds, &strategy.actions.actions_list(), &train_criterion, &val_criterion)
    }

    pub fn run_fold<T: Network + Clone + Serialize, P: Penalties<T>, A: Actions<T>>(&self, experiment: &Experiment<T, P, A>) -> FoldResults {
        let strategy = &experiment.strategy;
        let schema = &experiment.backtest_schema;

        let opt_results = self.run_opt(strategy, schema);
        let best_train_net_value = construct_net(&strategy.base_net, &opt_results.best_train_seq, &strategy.actions);
        let best_val_net_value = construct_net(&strategy.base_net, &opt_results.best_val_seq, &strategy.actions);
        let best_train_net = to_value(&best_train_net_value).expect("network should serialize");
        let best_val_net = to_value(&best_val_net_value).expect("network should serialize");
        let mut net = best_val_net_value.clone();

        let train_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.train_range, self.train_close);
        let val_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.val_range, self.val_close);
        let test_results = run_backtest(&mut net, strategy, schema, self.feat_table, self.test_range, self.test_close);

        FoldResults {
            train_start_timestamp: self.train_start_timestamp.clone(),
            train_end_timestamp: self.train_end_timestamp.clone(),
            val_start_timestamp: self.val_start_timestamp.clone(),
            val_end_timestamp: self.val_end_timestamp.clone(),
            test_start_timestamp: self.test_start_timestamp.clone(),
            test_end_timestamp: self.test_end_timestamp.clone(),
            train_results,
            val_results,
            test_results,
            best_train_net,
            best_val_net,
            opt_results
        }
    }
}

impl<T: Network, P: Penalties<T>, A: Actions<T>> Experiment<T, P, A> {
    fn get_fold_config(&self, data_len: usize) -> FoldConfig {
        let data_len_f64 = data_len as f64;
        let fold_len = (data_len_f64 * self.fold_size) as usize;
        let fold_len_f64 = fold_len as f64;

        let range = data_len - fold_len;
        let divisor = if self.cv_folds > 1 {
            self.cv_folds - 1
        } else {
            1
        };
        let stride = range / divisor;

        let test_frac = 1.0 - self.test_size;
        let test_offset = (test_frac * fold_len_f64) as usize;

        let val_frac = test_frac - self.val_size;
        let val_offset = (val_frac * fold_len_f64) as usize;

        FoldConfig {
            fold_len,
            stride,
            val_offset,
            test_offset
        }
    }

    fn get_fold<'a>(&self, fold_idx: usize, fold_config: &FoldConfig, close: &'a [f64], feat_table: &'a TimestampedTable) -> FoldData<'a> {
        let start_idx = fold_idx * fold_config.stride;
        let val_split = start_idx + fold_config.val_offset;
        let test_split = start_idx + fold_config.test_offset;
        let end_idx = if fold_idx == self.cv_folds - 1 { close.len() - 1 } else {
            start_idx + fold_config.fold_len - 1
        };
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

        FoldData::new(close, feat_table, train_range, val_range, test_range)
    }

    pub fn get_folds<'a>(&self, close: &'a [f64], feat_table: &'a TimestampedTable) -> Vec<FoldData<'a>> {
        let fold_config = self.get_fold_config(close.len());
        let mut folds = Vec::with_capacity(self.cv_folds);

        for fold_idx in 0..self.cv_folds {
            let fold = self.get_fold(
                fold_idx,
                &fold_config,
                close,
                feat_table
            );
            folds.push(fold);
        }

        folds
    }
}

pub async fn run_experiment<T: Network + Clone + Serialize, P: Penalties<T>, A: Actions<T>>(experiment: &Experiment<T, P, A>) -> Result<Vec<FoldResults>, String> {
    let data = fetch_ohlc(&experiment.symbol, &experiment.start_timestamp, &experiment.end_timestamp)?;
    let close = data.table.get("close").unwrap();
    let feat_values = feat_table(&experiment.strategy.feats, &data);
    let folds = experiment.get_folds(close.as_slice(), &feat_values);

    let results = folds.iter().map(|fold| fold.run_fold(experiment)).collect();

    Ok(results)
}


pub enum ExperimentVariant {
    Logic(Experiment<LogicNet, LogicPenalties, LogicActions>),
    Decision(Experiment<DecisionNet, DecisionPenalties, DecisionActions>)
}

impl ExperimentVariant {
    // Serialize the parsed experiment into the canonical `experiment` jsonb column shape.
    pub fn to_json(&self) -> Value {
        match self {
            ExperimentVariant::Logic(experiment) => experiment.to_json(),
            ExperimentVariant::Decision(experiment) => experiment.to_json()
        }
    }
}
