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

use super::strategy::{DataRange, NetSignals, Strategy};
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

#[derive(Debug)]
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

    fn net_signals(&self, strategy: &Strategy<T, P, A>, net: &mut T, feat_table: &TimestampedTable, data_range: DataRange, delay: usize) -> Vec<NetSignals> {
        strategy.net_signals(net, feat_table, data_range, delay)
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
        let signals = deps.net_signals(&self.strategy, net, feat_table, data_range, self.backtest_schema.delay);

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
                data_range,
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::collections::HashMap;
    use std::rc::Rc;
    use approx::assert_relative_eq;
    use hegel::TestCase;
    use hegel::generators::booleans;
    use mockall::Sequence;
    use mockall::predicate::{always, eq};
    use crate::experiment::backtest::{BacktestMetric, BacktestState};
    use crate::experiment::strategy::tests::{gen_data_range, gen_strategy};
    use crate::features::features::tests::gen_feat_table;
    use crate::network::logic_net::tests::gen_logic_net;
    use crate::optimizer::optimizer::Objective;
    use crate::optimizer::optimizer::tests::gen_action_seq;
    use crate::test_utils::{gen_f64, gen_text, gen_usize, gen_usize_between, gen_usize_with_max, gen_vec};

    const N_BARS: usize = 100;

    fn all_metrics() -> Vec<BacktestMetric> {
        vec![BacktestMetric::Sharpe, BacktestMetric::ExcessSharpe, BacktestMetric::MaxDrawdown, BacktestMetric::TotalEntries]
    }

    fn ohlc_table() -> TimestampedTable {
        let timestamps = (0..N_BARS).map(|i| format!("t{i}")).collect();
        let close = (0..N_BARS).map(|i| i as f64).collect();
        let mut table = HashMap::new();
        table.insert("close".to_string(), close);

        TimestampedTable { timestamps, table }
    }

    fn fold_data<'a>(close: &'a [f64], feat_table: &'a TimestampedTable, train_range: DataRange, val_range: DataRange, test_range: DataRange) -> FoldData<'a> {
        FoldData {
            train_close: close,
            val_close: close,
            test_close: close,
            feat_table,
            train_range,
            val_range,
            test_range,
            train_start_timestamp: "train_start".to_string(),
            train_end_timestamp: "train_end".to_string(),
            val_start_timestamp: "val_start".to_string(),
            val_end_timestamp: "val_end".to_string(),
            test_start_timestamp: "test_start".to_string(),
            test_end_timestamp: "test_end".to_string()
        }
    }

    #[hegel::composite]
    fn gen_objectives(tc: TestCase) -> Vec<Objective> {
        let n_objectives = tc.draw(gen_usize_with_max(3)) + 1;
        let metrics = all_metrics();
        let mut objectives = Vec::with_capacity(n_objectives);

        for metric in metrics.into_iter().take(n_objectives) {
            let weight = tc.draw(gen_f64());
            let objective = Objective { metric, weight };
            objectives.push(objective);
        }

        objectives
    }

    #[hegel::composite]
    fn gen_net_signals(tc: TestCase, len: usize) -> Vec<NetSignals> {
        (0..len).map(|_| {
            NetSignals { entry: tc.draw(booleans()), exit: tc.draw(booleans()) }
        }).collect()
    }

    #[hegel::composite]
    fn gen_backtest_results(tc: TestCase, objectives: &[Objective]) -> BacktestResults {
        let mut metrics = HashMap::new();

        for objective in objectives {
            let value = tc.draw(gen_f64());
            metrics.insert(objective.metric.clone(), value);
        }

        let final_state = BacktestState {
            net_signals: Vec::new(),
            close_prices: Vec::new(),
            balance: tc.draw(gen_f64()),
            equity: Vec::new(),
            lot: None,
            entries: 0,
            total_exits: 0,
            signal_exits: 0,
            take_profit_exits: 0,
            stop_loss_exits: 0,
            max_hold_exits: 0,
            hold_times: Vec::new()
        };

        BacktestResults { metrics, is_invalid: false, n_bars: 0, final_state }
    }

    #[hegel::composite]
    fn gen_iters_state(tc: TestCase) -> ItersState {
        ItersState {
            iters: tc.draw(gen_usize()),
            train_improvements: Vec::new(),
            val_improvements: Vec::new(),
            best_train_seq: tc.draw(gen_action_seq(3)),
            best_val_seq: tc.draw(gen_action_seq(3)),
            best_train_score: tc.draw(gen_f64()),
            best_val_score: tc.draw(gen_f64())
        }
    }

    #[hegel::composite]
    fn gen_fold_results(tc: TestCase, objectives: &[Objective]) -> FoldResults {
        FoldResults {
            train_start_timestamp: tc.draw(gen_text()),
            train_end_timestamp: tc.draw(gen_text()),
            val_start_timestamp: tc.draw(gen_text()),
            val_end_timestamp: tc.draw(gen_text()),
            test_start_timestamp: tc.draw(gen_text()),
            test_end_timestamp: tc.draw(gen_text()),
            train_results: tc.draw(gen_backtest_results(objectives)),
            val_results: tc.draw(gen_backtest_results(objectives)),
            test_results: tc.draw(gen_backtest_results(objectives)),
            best_train_net: Value::Null,
            best_val_net: Value::Null,
            opt_results: tc.draw(gen_iters_state())
        }
    }

    #[hegel::composite]
    fn gen_experiment(tc: TestCase, objectives: Option<&[Objective]>) -> Experiment<LogicNet, LogicPenalties, LogicActions> {
        let strategy = tc.draw(gen_strategy(None, objectives));
        let delay = tc.draw(gen_usize_with_max(3));
        let backtest_schema = BacktestSchema {
            start_offset: 0,
            start_balance: tc.draw(gen_f64()),
            delay,
            metrics: all_metrics()
        };

        Experiment {
            val_size: 0.2,
            test_size: 0.2,
            cv_folds: 2,
            fold_size: 0.5,
            symbol: "BTC_USDT".to_string(),
            start_timestamp: tc.draw(gen_text()),
            end_timestamp: tc.draw(gen_text()),
            backtest_schema,
            strategy
        }
    }

    #[hegel::test]
    fn test_run_backtest(tc: TestCase) {
        let objectives = tc.draw(gen_objectives());
        let experiment = tc.draw(gen_experiment(Some(&objectives)));
        let feat_table = tc.draw(gen_feat_table());
        let mut net = tc.draw(gen_logic_net(Some(false), None));
        let n_rows = tc.draw(gen_usize_between(2, 10));
        let data_range = tc.draw(gen_data_range(n_rows));
        let close_prices = tc.draw(gen_vec(gen_f64(), n_rows));
        let signals = tc.draw(gen_net_signals(n_rows));
        let results = tc.draw(gen_backtest_results(&objectives));
        let expected_metrics = results.metrics.clone();
        let delay = experiment.backtest_schema.delay;

        let mut mock_deps = MockExperimentDeps::new();

        let eq_data_range = eq(data_range);
        let eq_delay = eq(delay);

        let net_signals_dep = mock_deps.expect_net_signals().times(1);
        let net_signals_dep = net_signals_dep.with(always(), always(), always(), eq_data_range, eq_delay);
        net_signals_dep.return_const(signals);

        let backtest_dep = mock_deps.expect_backtest().times(1);
        backtest_dep.return_const(results);

        let value = experiment._run_backtest(&mock_deps, &mut net, &feat_table, data_range, &close_prices);

        assert_eq!(value.metrics, expected_metrics);
    }

    #[hegel::test]
    fn test_criterion(tc: TestCase) {
        let objectives = tc.draw(gen_objectives());
        let experiment = tc.draw(gen_experiment(Some(&objectives)));
        let feat_table = tc.draw(gen_feat_table());
        let n_rows = tc.draw(gen_usize_between(2, 10));
        let data_range = tc.draw(gen_data_range(n_rows));
        let close_prices = tc.draw(gen_vec(gen_f64(), n_rows));
        let signals = tc.draw(gen_net_signals(n_rows));
        let results = tc.draw(gen_backtest_results(&objectives));
        let net = tc.draw(gen_logic_net(Some(false), None));
        let penalty = tc.draw(gen_f64());
        let seq = tc.draw(gen_action_seq(3));

        let mut opt_score = 0.0;
        for objective in &objectives {
            let weighted = objective.weight * results.metrics[&objective.metric];
            opt_score += weighted;
        }
        let expected_score = opt_score - penalty;

        let mut mock_deps = MockExperimentDeps::new();

        let construct_net_dep = mock_deps.expect_construct_net().times(1);
        construct_net_dep.return_const(net);

        let net_signals_dep = mock_deps.expect_net_signals().times(1);
        net_signals_dep.return_const(signals);

        let backtest_dep = mock_deps.expect_backtest().times(1);
        backtest_dep.return_const(results);

        let penalty_dep = mock_deps.expect_penalty().times(1);
        penalty_dep.return_const(penalty);

        let criterion = experiment._criterion(&mock_deps, &feat_table, data_range, &close_prices);
        let score = criterion(&seq);

        assert_relative_eq!(score, expected_score, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_run_opt(tc: TestCase) {
        let objectives = tc.draw(gen_objectives());
        let experiment = tc.draw(gen_experiment(Some(&objectives)));
        let feat_table = tc.draw(gen_feat_table());
        let close_prices = tc.draw(gen_vec(gen_f64(), 5));
        let train_range = tc.draw(gen_data_range(2));
        let val_range = tc.draw(gen_data_range(3));
        let test_range = tc.draw(gen_data_range(4));
        let fold = fold_data(&close_prices, &feat_table, train_range, val_range, test_range);

        let iters_state = tc.draw(gen_iters_state());
        let expected_iters = iters_state.iters;
        let expected_train_seq = iters_state.best_train_seq.clone();
        let expected_val_seq = iters_state.best_val_seq.clone();

        let mut mock_deps = MockExperimentDeps::new();

        let run_genetic_dep = mock_deps.expect_run_genetic().times(1);
        run_genetic_dep.return_const(iters_state);

        let state = experiment._run_opt(&mock_deps, &fold);

        assert_eq!(state.iters, expected_iters);
        assert_eq!(state.best_train_seq, expected_train_seq);
        assert_eq!(state.best_val_seq, expected_val_seq);
    }

    #[hegel::test]
    fn test_run_fold(tc: TestCase) {
        let objectives = tc.draw(gen_objectives());
        let experiment = tc.draw(gen_experiment(Some(&objectives)));
        let feat_table = tc.draw(gen_feat_table());
        let close_prices = tc.draw(gen_vec(gen_f64(), 5));
        let train_range = tc.draw(gen_data_range(2));
        let val_range = tc.draw(gen_data_range(3));
        let test_range = tc.draw(gen_data_range(4));
        tc.assume(train_range != val_range);
        tc.assume(val_range != test_range);
        tc.assume(train_range != test_range);

        let fold = fold_data(&close_prices, &feat_table, train_range, val_range, test_range);
        let iters_state = tc.draw(gen_iters_state());
        let train_net = tc.draw(gen_logic_net(Some(false), None));
        let val_net = tc.draw(gen_logic_net(Some(false), None));
        let train_results = tc.draw(gen_backtest_results(&objectives));
        let val_results = tc.draw(gen_backtest_results(&objectives));
        let test_results = tc.draw(gen_backtest_results(&objectives));
        let expected_train_metrics = train_results.metrics.clone();
        let expected_val_metrics = val_results.metrics.clone();
        let expected_test_metrics = test_results.metrics.clone();

        let seen_nets: Rc<RefCell<Vec<LogicNet>>> = Rc::new(RefCell::new(Vec::new()));
        let mut mock_deps: MockExperimentDeps<LogicNet, LogicPenalties, LogicActions> = MockExperimentDeps::new();
        let mut sequence = Sequence::new();

        let run_opt_dep = mock_deps.expect_run_opt().times(1);
        run_opt_dep.return_const(iters_state);

        let train_net_dep = mock_deps.expect_construct_net().times(1);
        let train_net_dep = train_net_dep.in_sequence(&mut sequence);
        train_net_dep.return_const(train_net.clone());

        let val_net_dep = mock_deps.expect_construct_net().times(1);
        let val_net_dep = val_net_dep.in_sequence(&mut sequence);
        val_net_dep.return_const(val_net.clone());

        let train_nets_return = Rc::clone(&seen_nets);
        let eq_train_range = eq(train_range);
        let train_bt_dep = mock_deps.expect_run_backtest().times(1);
        let train_bt_dep = train_bt_dep.with(always(), always(), always(), eq_train_range, always());
        train_bt_dep.returning_st(move |_, net, _, _, _| {
            train_nets_return.borrow_mut().push(net.clone());
            train_results.clone()
        });

        let val_nets_return = Rc::clone(&seen_nets);
        let eq_val_range = eq(val_range);
        let val_bt_dep = mock_deps.expect_run_backtest().times(1);
        let val_bt_dep = val_bt_dep.with(always(), always(), always(), eq_val_range, always());
        val_bt_dep.returning_st(move |_, net, _, _, _| {
            val_nets_return.borrow_mut().push(net.clone());
            val_results.clone()
        });

        let test_nets_return = Rc::clone(&seen_nets);
        let eq_test_range = eq(test_range);
        let test_bt_dep = mock_deps.expect_run_backtest().times(1);
        let test_bt_dep = test_bt_dep.with(always(), always(), always(), eq_test_range, always());
        test_bt_dep.returning_st(move |_, net, _, _, _| {
            test_nets_return.borrow_mut().push(net.clone());
            test_results.clone()
        });

        let results = experiment._run_fold(&mock_deps, &fold);

        assert_eq!(results.train_start_timestamp, "train_start");
        assert_eq!(results.test_end_timestamp, "test_end");
        assert_eq!(results.best_train_net, to_value(&train_net).unwrap());
        assert_eq!(results.best_val_net, to_value(&val_net).unwrap());
        assert_eq!(results.train_results.metrics, expected_train_metrics);
        assert_eq!(results.val_results.metrics, expected_val_metrics);
        assert_eq!(results.test_results.metrics, expected_test_metrics);

        // Every backtest runs the best_val net, never the best_train one.
        let expected_nets = vec![val_net.clone(), val_net.clone(), val_net];
        assert_eq!(*seen_nets.borrow(), expected_nets);
    }

    #[hegel::test]
    fn test_run(tc: TestCase) {
        let objectives = tc.draw(gen_objectives());
        let experiment = tc.draw(gen_experiment(Some(&objectives)));
        let fold_results = tc.draw(gen_fold_results(&objectives));
        let cv_folds = experiment.cv_folds;

        let mut mock_deps = MockExperimentDeps::new();

        let fetch_ohlc_dep = mock_deps.expect_fetch_ohlc().times(1);
        fetch_ohlc_dep.returning(|_, _, _| Ok(ohlc_table()));

        let feat_table_dep = mock_deps.expect_feat_table().times(1);
        feat_table_dep.returning(|_, _| ohlc_table());

        let run_fold_dep = mock_deps.expect_run_fold().times(cv_folds);
        run_fold_dep.return_const(fold_results);

        let results = experiment._run(&mock_deps).unwrap();

        assert_eq!(results.len(), cv_folds);
    }

    #[hegel::test]
    fn test_run_fetch_error(tc: TestCase) {
        let objectives = tc.draw(gen_objectives());
        let experiment = tc.draw(gen_experiment(Some(&objectives)));
        let message = tc.draw(gen_text());
        let expected_message = message.clone();

        let mut mock_deps = MockExperimentDeps::new();

        let fetch_ohlc_dep = mock_deps.expect_fetch_ohlc().times(1);
        fetch_ohlc_dep.returning(move |_, _, _| Err(message.clone()));
        mock_deps.expect_feat_table().times(0);
        mock_deps.expect_run_fold().times(0);

        let error = experiment._run(&mock_deps).unwrap_err();

        assert_eq!(error, expected_message);
    }
}
