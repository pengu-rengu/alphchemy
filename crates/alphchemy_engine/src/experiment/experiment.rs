use serde::Serialize;
use serde_json::{Value, json, to_value};

use crate::fetch_data::fetch_ohlc;
use crate::network::network::{Network, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties};
use crate::features::features::{Feature, TimestampedTable};
use crate::features::features::feat_table;
use crate::actions::actions::{Action, Actions, construct_net};
use crate::actions::logic_actions::LogicActions;
use crate::actions::decision_actions::DecisionActions;
use crate::optimizer::optimizer::{ItersState, Scorer, StopConds};
use crate::optimizer::genetic::GeneticOpt;

use super::strategy::{NetSignals, Strategy};
use super::backtest::{BacktestSchema, BacktestResults, backtest};
#[cfg(test)]
use mockall::automock;

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
    fn new(close: &'a [f64],
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

#[cfg_attr(test, automock)]
trait ExperimentDeps<T: Network + Clone + Serialize, P: Penalties<T>, A: Actions<T>> {
    fn construct_net(&self, base_net: &T, seq: &[Action], actions: &A) -> T {
        construct_net(base_net, seq, actions)
    }

    fn net_signals(&self, strategy: &Strategy<T, P, A>, net: &mut T, feat_table: &TimestampedTable, start_idx: usize, end_idx: usize, delay: usize) -> Vec<NetSignals> {
        strategy.net_signals(net, feat_table, start_idx, end_idx, delay)
    }

    fn backtest(&self, signals: Vec<NetSignals>, strategy: &Strategy<T, P, A>, schema: &BacktestSchema, close_prices: &[f64]) -> BacktestResults {
        backtest(signals, strategy.qty, strategy.stop_loss, strategy.take_profit, strategy.max_hold_time, schema, close_prices)
    }

    fn penalty(&self, strategy: &Strategy<T, P, A>, net: &T) -> f64 {
        strategy.penalties.penalty(net, strategy.feats.len())
    }

    fn fetch_ohlc(&self, symbol: &str, start_timestamp: &str, end_timestamp: &str) -> Result<TimestampedTable, String> {
        fetch_ohlc(symbol, start_timestamp, end_timestamp)
    }

    fn feat_table(&self, feats: &[Feature], data: &TimestampedTable) -> TimestampedTable {
        feat_table(feats, data)
    }

    fn run_backtest(&self, experiment: &Experiment<T, P, A>, net: &mut T, feat_table: &TimestampedTable, data_range: DataRange, close_prices: &[f64]) -> BacktestResults {
        experiment._run_backtest(&ExperimentDepsImpl, net, feat_table, data_range, close_prices)
    }

    fn run_genetic(&self, opt: &GeneticOpt, stop_conds: &StopConds, actions_list: &[Action], train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> ItersState {
        opt.run_genetic(stop_conds, actions_list, train_scorer, val_scorer)
    }

    fn run_opt<'a>(&self, experiment: &Experiment<T, P, A>, fold: &FoldData<'a>) -> ItersState {
        experiment._run_opt(&ExperimentDepsImpl, fold)
    }

    fn run_fold<'a>(&self, experiment: &Experiment<T, P, A>, fold: &FoldData<'a>) -> FoldResults {
        experiment._run_fold(&ExperimentDepsImpl, fold)
    }
}

struct ExperimentDepsImpl;
impl<T: Network + Clone + Serialize, P: Penalties<T>, A: Actions<T>> ExperimentDeps<T, P, A> for ExperimentDepsImpl {}

impl<T: Network + Clone + Serialize, P: Penalties<T>, A: Actions<T>> Experiment<T, P, A> {
    fn _run_backtest<D>(&self, deps: &D, net: &mut T, feat_table: &TimestampedTable, data_range: DataRange, close_prices: &[f64]) -> BacktestResults where D: ExperimentDeps<T, P, A> {
        let signals = deps.net_signals(&self.strategy, net, feat_table, data_range.start_idx, data_range.end_idx, self.backtest_schema.delay);

        deps.backtest(signals, &self.strategy, &self.backtest_schema, close_prices)
    }

    fn _criterion<'a, D>(&'a self, deps: &'a D, feat_table: &'a TimestampedTable, data_range: DataRange, close_prices: &'a [f64]) -> impl Fn(&[Action]) -> f64 + 'a where D: ExperimentDeps<T, P, A> {
        move |seq: &[Action]| {
            let strategy = &self.strategy;
            let mut net = deps.construct_net(&strategy.base_net, seq, &strategy.actions);

            let signals = deps.net_signals(
                strategy,
                &mut net,
                feat_table,
                data_range.start_idx,
                data_range.end_idx,
                self.backtest_schema.delay
            );

            let results = deps.backtest(signals, strategy, &self.backtest_schema, close_prices);
            let opt_score: f64 = strategy.opt.objectives.iter().map(|objective| objective.weight * results.metrics[&objective.metric]).sum();

            let penalty_score = deps.penalty(strategy, &net);

            opt_score - penalty_score
        }
    }

    fn criterion<'a>(&'a self, feat_table: &'a TimestampedTable, data_range: DataRange, close_prices: &'a [f64]) -> impl Fn(&[Action]) -> f64 + 'a {
        self._criterion(&ExperimentDepsImpl, feat_table, data_range, close_prices)
    }

    fn _run_opt<D>(&self, deps: &D, fold: &FoldData) -> ItersState where D: ExperimentDeps<T, P, A> {
        let strategy = &self.strategy;
        let train_criterion = self.criterion(fold.feat_table, fold.train_range, fold.train_close);
        let val_criterion = self.criterion(fold.feat_table, fold.val_range, fold.val_close);

        deps.run_genetic(&strategy.opt, &strategy.stop_conds, &strategy.actions.actions_list(), &train_criterion, &val_criterion)
    }

    fn _run_fold<D>(&self, deps: &D, fold: &FoldData) -> FoldResults where D: ExperimentDeps<T, P, A> {
        let strategy = &self.strategy;

        let opt_results = deps.run_opt(self, fold);
        let best_train_net_value = deps.construct_net(&strategy.base_net, &opt_results.best_train_seq, &strategy.actions);
        let best_val_net_value = deps.construct_net(&strategy.base_net, &opt_results.best_val_seq, &strategy.actions);
        let best_train_net = to_value(&best_train_net_value).expect("network should serialize");
        let best_val_net = to_value(&best_val_net_value).expect("network should serialize");
        let mut net = best_val_net_value.clone();

        let train_results = deps.run_backtest(self, &mut net, fold.feat_table, fold.train_range, fold.train_close);
        let val_results = deps.run_backtest(self, &mut net, fold.feat_table, fold.val_range, fold.val_close);
        let test_results = deps.run_backtest(self, &mut net, fold.feat_table, fold.test_range, fold.test_close);

        FoldResults {
            train_start_timestamp: fold.train_start_timestamp.clone(),
            train_end_timestamp: fold.train_end_timestamp.clone(),
            val_start_timestamp: fold.val_start_timestamp.clone(),
            val_end_timestamp: fold.val_end_timestamp.clone(),
            test_start_timestamp: fold.test_start_timestamp.clone(),
            test_end_timestamp: fold.test_end_timestamp.clone(),
            train_results,
            val_results,
            test_results,
            best_train_net,
            best_val_net,
            opt_results
        }
    }

    fn _run<D>(&self, deps: &D) -> Result<Vec<FoldResults>, String> where D: ExperimentDeps<T, P, A> {
        let data = deps.fetch_ohlc(&self.symbol, &self.start_timestamp, &self.end_timestamp)?;
        let feat_values = deps.feat_table(&self.strategy.feats, &data);
        let folds = self.get_folds( &data.table["close"], &feat_values);

        Ok(folds.iter().map(|fold| {
            deps.run_fold(self, fold)}
        ).collect())
    }

    pub async fn run(&self) -> Result<Vec<FoldResults>, String> {
        self._run(&ExperimentDepsImpl)
    }
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
