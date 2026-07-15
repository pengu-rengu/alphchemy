use std::collections::HashMap;
use serde::Serialize;
use crate::utils::std_dev;
use super::strategy::NetSignals;
#[cfg(test)]
use mockall::automock;

#[derive(Hash, PartialEq, Eq, Clone, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum BacktestMetric {
    Sharpe, ExcessSharpe, MaxDrawdown, MeanHoldTime, StdHoldTime, TotalEntries, TotalExits, SignalExits, StopLossExits, TakeProfitExits, MaxHoldExits
}

#[derive(Clone, Debug, Serialize)]
pub struct BacktestSchema {
    pub start_offset: usize,
    pub start_balance: f64,
    pub delay: usize,
    pub metrics: Vec<BacktestMetric>
}

struct ExitConds {
    take_profit: bool,
    stop_loss: bool,
    max_hold: bool
}

impl ExitConds {
    fn any(&self) -> bool {
        self.take_profit || self.stop_loss || self.max_hold
    }
}

#[derive(Clone, Debug)]
pub struct Lot {
    pub enter_price: f64,
    pub size: f64,
    pub enter_idx: usize
}

#[derive(Clone, Debug)]
pub struct BacktestState {
    pub net_signals: Vec<NetSignals>,
    pub close_prices: Vec<f64>,
    pub balance: f64,
    pub equity: Vec<f64>,
    pub lot: Option<Lot>,
    pub entries: usize,
    pub total_exits: usize,
    pub signal_exits: usize,
    pub take_profit_exits: usize,
    pub stop_loss_exits: usize,
    pub max_hold_exits: usize,
    pub hold_times: Vec<usize>
}

#[derive(Clone, Debug)]
pub struct BacktestResults {
    pub metrics: HashMap<BacktestMetric, f64>,
    pub is_invalid: bool,
    pub n_bars: usize,
    pub final_state: BacktestState
}

#[cfg_attr(test, automock)]
trait BacktestDeps {
    fn log_returns(&self, values: &[f64]) -> Vec<f64> {
        if values.len() < 2 {
            return Vec::new();
        }
        let mut returns = Vec::with_capacity(values.len() - 1);
        for i in 1..values.len() {
            returns.push((values[i] / values[i - 1]).ln());
        }
        returns
    }

    fn std_dev(&self, values: &[f64]) -> f64 {
        std_dev(values)
    }

    fn max_drawdown(&self, values: &[f64]) -> f64 {
        let mut peak = f64::MIN;
        let mut max_dd = 0.0;
        for &value in values {
            if value > peak {
                peak = value;
            }
            let drop = peak - value;
            let drawdown = drop / peak;
            if drawdown > max_dd {
                max_dd = drawdown;
            }
        }
        max_dd
    }

    fn sharpe(&self, values: &[f64]) -> f64 {
        _sharpe(&BacktestDepsImpl, values)
    }

    fn exit_conds(&self, lot: &Lot, stop_loss: f64, take_profit: f64, max_hold_time: usize, current_close: f64, idx: usize) -> ExitConds {
        ExitConds {
            take_profit: current_close > lot.enter_price * (1.0 + take_profit),
            stop_loss: current_close < lot.enter_price * (1.0 - stop_loss),
            max_hold: idx - lot.enter_idx >= max_hold_time
        }
    }

    fn close_lot(&self, state: &mut BacktestState, lot: &Lot, idx: usize) {
        state.balance += state.close_prices[idx] * lot.size;

        state.hold_times.push(idx - lot.enter_idx);
        state.total_exits += 1;
    }

    fn risk_exits_update(&self, state: &mut BacktestState, stop_loss: f64, take_profit: f64, max_hold_time: usize, idx: usize) {
        state._risk_exits_update(&BacktestDepsImpl, stop_loss, take_profit, max_hold_time, idx);
    }

    fn signal_exits_update(&self, state: &mut BacktestState, idx: usize) {
        state._signal_exits_update(&BacktestDepsImpl, idx);
    }

    fn try_open_lot(&self, state: &mut BacktestState, qty: f64, idx: usize) {
        if state.lot.is_some() || !state.net_signals[idx].entry {
            return;
        }

        let curr_close = state.close_prices[idx];
        let cost = qty * curr_close;

        if cost > state.balance {
            return;
        }

        state.lot = Some( Lot {
            enter_price: curr_close,
            size: qty,
            enter_idx: idx
        });
        state.balance -= cost;
        state.entries += 1;
    }

    fn update_equity(&self, state: &mut BacktestState, schema: &BacktestSchema, idx: usize) {
        let market_value = match &state.lot {
            Some(lot) => lot.size * state.close_prices[idx],
            None => 0.0
        };

        let equity_idx = idx - schema.start_offset;
        state.equity[equity_idx] = state.balance + market_value;
    }

    fn results(&self, state: BacktestState, schema: &BacktestSchema) -> BacktestResults {
        let is_invalid = state.equity.iter().any(|&value| value < 0.0) || state.total_exits == 0;
        let metrics = state.metrics_map(schema, is_invalid);
        let n_bars = state.equity.len();

        BacktestResults {
            metrics,
            is_invalid,
            n_bars,
            final_state: state
        }
    }
}

struct BacktestDepsImpl;
impl BacktestDeps for BacktestDepsImpl {}

impl BacktestState {
    fn new(net_signals: Vec<NetSignals>, schema: &BacktestSchema, close_prices: &[f64]) -> Self {
        let equity_len = close_prices.len().saturating_sub(schema.start_offset);

        BacktestState {
            net_signals,
            close_prices: close_prices.to_vec(),
            balance: schema.start_balance,
            equity: vec![0.0; equity_len],
            lot: None,
            entries: 0,
            total_exits: 0,
            signal_exits: 0,
            take_profit_exits: 0,
            stop_loss_exits: 0,
            max_hold_exits: 0,
            hold_times: Vec::new()
        }
    }

    fn _risk_exits_update<D>(&mut self, deps: &D, stop_loss: f64, take_profit: f64, max_hold_time: usize, idx: usize) where D: BacktestDeps {
        let curr_close = self.close_prices[idx];

        let Some(lot_ref) = &self.lot else { return; };

        let conds = deps.exit_conds(lot_ref, stop_loss, take_profit, max_hold_time, curr_close, idx);
        if !conds.any() {
            return;
        }

        let lot = self.lot.take().unwrap();
        deps.close_lot(self, &lot, idx);

        if conds.take_profit {
            self.take_profit_exits += 1;
        }
        if conds.stop_loss {
            self.stop_loss_exits += 1;
        }
        if conds.max_hold {
            self.max_hold_exits += 1;
        }
    }

    fn _signal_exits_update<D>(&mut self, deps: &D, idx: usize) where D: BacktestDeps {
        if !self.net_signals[idx].exit || self.lot.is_none() {
            return;
        }

        let lot = self.lot.take().unwrap();
        deps.close_lot(self, &lot, idx);
        self.signal_exits += 1;
    }

    fn _compute_metric<D>(&self, deps: &D, metric: &BacktestMetric, schema: &BacktestSchema) -> f64 where D: BacktestDeps {
        match metric {
            BacktestMetric::Sharpe => deps.sharpe(&self.equity),
            BacktestMetric::ExcessSharpe => {
                let equity_sharpe = deps.sharpe(&self.equity);
                let close_sharpe = deps.sharpe(&self.close_prices[schema.start_offset..]);
                equity_sharpe - close_sharpe
            }
            BacktestMetric::MaxDrawdown => deps.max_drawdown(&self.equity),
            BacktestMetric::MeanHoldTime => {
                let count = self.hold_times.len() as f64;
                let sum = self.hold_times.iter().sum::<usize>() as f64;
                sum / count
            }
            BacktestMetric::StdHoldTime => {
                let hold_times_f64 = self.hold_times.iter().map(|&value| value as f64).collect::<Vec<f64>>();
                deps.std_dev(&hold_times_f64)
            }
            BacktestMetric::TotalEntries => self.entries as f64,
            BacktestMetric::TotalExits => self.total_exits as f64,
            BacktestMetric::SignalExits => self.signal_exits as f64,
            BacktestMetric::StopLossExits => self.stop_loss_exits as f64,
            BacktestMetric::TakeProfitExits => self.take_profit_exits as f64,
            BacktestMetric::MaxHoldExits => self.max_hold_exits as f64
        }
    }

    fn compute_metric(&self, metric: &BacktestMetric, schema: &BacktestSchema) -> f64 {
        self._compute_metric(&BacktestDepsImpl, metric, schema)
    }

    fn metrics_map(&self, schema: &BacktestSchema, is_invalid: bool) -> HashMap<BacktestMetric, f64> {
        let mut metrics = HashMap::new();

        for metric in &schema.metrics {
            let value = if is_invalid { 0.0 } else { self.compute_metric(metric, schema) };
            let key = metric.clone();
            metrics.insert(key, value);
        }

        metrics
    }

}

fn _sharpe<D>(deps: &D, values: &[f64]) -> f64 where D: BacktestDeps {
    let returns = deps.log_returns(values);
    let len = returns.len();
    if len < 2 {
        return 0.0;
    }
    
    let std = deps.std_dev(&returns);
    if std == 0.0 {
        return 0.0;
    }

    let mean = returns.iter().sum::<f64>() / len as f64;
    mean / std
}

#[allow(clippy::too_many_arguments)]
fn _backtest<T>(deps: &T, net_signals: Vec<NetSignals>, qty: f64, stop_loss: f64, take_profit: f64, max_hold_time: usize, schema: &BacktestSchema, close_prices: &[f64]) -> BacktestResults where T: BacktestDeps {
    let mut state = BacktestState::new(net_signals, schema, close_prices);
    let close_len = state.close_prices.len();

    for i in schema.start_offset..close_len {
        deps.risk_exits_update(&mut state, stop_loss, take_profit, max_hold_time, i);
        deps.signal_exits_update(&mut state, i);
        deps.try_open_lot(&mut state, qty, i);
        deps.update_equity(&mut state, schema, i);
    }

    deps.results(state, schema)
}

pub fn backtest(net_signals: Vec<NetSignals>, qty: f64, stop_loss: f64, take_profit: f64, max_hold_time: usize, schema: &BacktestSchema, close_prices: &[f64]) -> BacktestResults {
    _backtest(&BacktestDepsImpl, net_signals, qty, stop_loss, take_profit, max_hold_time, schema, close_prices)
}

#[cfg(test)]
mod tests {
    use super::*;
    use approx::assert_relative_eq;
    use hegel::{TestCase, generators::booleans};
    use mockall::Sequence;
    use mockall::predicate::{always, eq};
    use crate::test_utils::{gen_f64, gen_usize, gen_usize_with_max, gen_usize_with_min, gen_vec};

    #[hegel::composite]
    fn gen_backtest_state(tc: TestCase) -> BacktestState {
        let len = tc.draw(gen_usize_with_min(1));
        let net_signals = (0..len).map(|_| {
            NetSignals {
                entry: tc.draw(booleans()),
                exit: tc.draw(booleans())
            }
        }).collect();

        let close_prices = tc.draw(gen_vec(gen_f64(), len));
        let schema = BacktestSchema {
            start_offset: 0,
            start_balance: tc.draw(gen_f64()),
            delay: 0,
            metrics: Vec::new()
        };

        BacktestState::new(net_signals, &schema, &close_prices)
    }

    #[hegel::test]
    fn test_log_returns(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(2));
        let mut values = tc.draw(gen_vec(gen_f64(), len));

        for value in &mut values {
            *value += 1e-5;
        }

        let returns = BacktestDepsImpl.log_returns(&values);

        for i in 1..len {
            assert_relative_eq!(returns[i - 1], (values[i] / values[i - 1]).ln(), epsilon = 1e-5);
        }
    }

    #[hegel::test]
    fn test_max_drawdown(tc: TestCase) {
        let peak = tc.draw(gen_f64()) + 1.0;
        let drawdown = tc.draw(gen_f64()) / 100.0;
        let trough_factor = 1.0 - drawdown;
        let trough = peak * trough_factor;
        let values = vec![peak, trough];

        let value = BacktestDepsImpl.max_drawdown(&values);

        assert_relative_eq!(value, drawdown, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_sharpe(tc: TestCase) {
        let len = tc.draw(gen_usize_with_min(2));
        let values = tc.draw(gen_vec(gen_f64(), len));

        let log_returns = tc.draw(gen_vec(gen_f64(), len));
        let std = tc.draw(gen_f64()) + 1.0;
        let mean = log_returns.iter().sum::<f64>() / len as f64;
        let mut mock_deps = MockBacktestDeps::new();

        let eq_values = eq(values.clone());

        let log_returns_dep = mock_deps.expect_log_returns().times(1);
        let log_returns_dep = log_returns_dep.with(eq_values);
        log_returns_dep.return_const(log_returns.clone());

        let eq_returns = eq(log_returns);

        let std_dev_dep = mock_deps.expect_std_dev().times(1);
        let std_dev_dep = std_dev_dep.with(eq_returns);
        std_dev_dep.return_const(std);

        let value = _sharpe(&mock_deps, &values);

        assert_relative_eq!(value, mean / std, epsilon = 1e-5);
    }

    #[hegel::test]
    fn test_risk_exits_update(tc: TestCase) {
        let mut state = tc.draw(gen_backtest_state());
        let idx = tc.draw(gen_usize_with_max(state.close_prices.len() - 1));
        
        let lot = Lot {
            enter_price: tc.draw(gen_f64()),
            size: tc.draw(gen_f64()),
            enter_idx: tc.draw(gen_usize_with_max(idx))
        };
        state.lot = Some(lot);

        let stop_loss = tc.draw(gen_f64());
        let take_profit = tc.draw(gen_f64());
        let max_hold_time = tc.draw(gen_usize());
        let take_profit_exit = tc.draw(booleans());
        let stop_loss_exit = tc.draw(booleans());
        let max_hold_exit = tc.draw(booleans());
        let any_exit = take_profit_exit || stop_loss_exit || max_hold_exit;
        tc.assume(any_exit);

        let current_close = state.close_prices[idx];
        let mut mock_deps = MockBacktestDeps::new();

        let eq_stop_loss = eq(stop_loss);
        let eq_take_profit = eq(take_profit);
        let eq_max_hold_time = eq(max_hold_time);
        let eq_current_close = eq(current_close);
        let eq_exit_idx = eq(idx);

        let exit_conds_dep = mock_deps.expect_exit_conds().times(1);
        let exit_conds_dep = exit_conds_dep.with(always(), eq_stop_loss, eq_take_profit, eq_max_hold_time, eq_current_close, eq_exit_idx);
        exit_conds_dep.returning(move |_, _, _, _, _, _| {
            ExitConds {
                take_profit: take_profit_exit,
                stop_loss: stop_loss_exit,
                max_hold: max_hold_exit
            }
        });

        let eq_close_idx = eq(idx);

        let close_lot_dep = mock_deps.expect_close_lot().times(1);
        let close_lot_dep = close_lot_dep.with(always(), always(), eq_close_idx);
        close_lot_dep.return_const(());

        state._risk_exits_update(&mock_deps, stop_loss, take_profit, max_hold_time, idx);

        let expected_take_profit = usize::from(take_profit_exit);
        let expected_stop_loss = usize::from(stop_loss_exit);
        let expected_max_hold = usize::from(max_hold_exit);
        assert!(state.lot.is_none());
        assert_eq!((state.take_profit_exits, state.stop_loss_exits, state.max_hold_exits), (expected_take_profit, expected_stop_loss, expected_max_hold));
    }

    #[hegel::test]
    fn test_signal_exits_update(tc: TestCase) {
        let mut state = tc.draw(gen_backtest_state());
        let idx = tc.draw(gen_usize_with_max(state.close_prices.len() - 1));
        
        state.net_signals[idx].exit = true;
        state.lot = Some(Lot {
            enter_price: tc.draw(gen_f64()),
            size: tc.draw(gen_f64()),
            enter_idx: tc.draw(gen_usize_with_max(idx))
        });

        let mut mock_deps = MockBacktestDeps::new();
        let eq_idx = eq(idx);

        let close_lot_dep = mock_deps.expect_close_lot().times(1);
        let close_lot_dep = close_lot_dep.with(always(), always(), eq_idx);
        close_lot_dep.return_const(());

        state._signal_exits_update(&mock_deps, idx);

        assert!(state.lot.is_none());
        assert_eq!(state.signal_exits, 1);
    }

    #[hegel::test]
    fn test_excess_sharpe(tc: TestCase) {
        let state = tc.draw(gen_backtest_state());
        let schema = BacktestSchema {
            start_offset: 0,
            start_balance: tc.draw(gen_f64()),
            delay: 0,
            metrics: Vec::new()
        };
        let equity_sharpe = tc.draw(gen_f64());
        let close_sharpe = tc.draw(gen_f64());
        let mut mock_deps = MockBacktestDeps::new();
        let mut sequence = Sequence::new();

        let eq_equity = eq(state.equity.clone());

        let equity_sharpe_dep = mock_deps.expect_sharpe().times(1);
        let equity_sharpe_dep = equity_sharpe_dep.with(eq_equity);
        let equity_sharpe_dep = equity_sharpe_dep.in_sequence(&mut sequence);
        equity_sharpe_dep.return_const(equity_sharpe);

        let eq_close_prices = eq(state.close_prices.clone());

        let close_sharpe_dep = mock_deps.expect_sharpe().times(1);
        let close_sharpe_dep = close_sharpe_dep.with(eq_close_prices);
        let close_sharpe_dep = close_sharpe_dep.in_sequence(&mut sequence);
        close_sharpe_dep.return_const(close_sharpe);

        let value = state._compute_metric(&mock_deps, &BacktestMetric::ExcessSharpe, &schema);

        assert_eq!(value, equity_sharpe - close_sharpe);
    }

    #[hegel::test]
    fn test_backtest(tc: TestCase) {
        let net_signals = vec![NetSignals {
            entry: tc.draw(booleans()),
            exit: tc.draw(booleans())
        }];
        let close_prices = vec![tc.draw(gen_f64())];
        let qty = tc.draw(gen_f64());
        let stop_loss = tc.draw(gen_f64());
        let take_profit = tc.draw(gen_f64());
        let max_hold_time = tc.draw(gen_usize());
        
        let schema = BacktestSchema {
            start_offset: 0,
            start_balance: tc.draw(gen_f64()),
            delay: 0,
            metrics: Vec::new()
        };
        let mut mock_deps = MockBacktestDeps::new();
        let mut sequence = Sequence::new();

        let eq_stop_loss = eq(stop_loss);
        let eq_take_profit = eq(take_profit);
        let eq_max_hold_time = eq(max_hold_time);
        let eq_risk_idx = eq(0);

        let risk_exits_dep = mock_deps.expect_risk_exits_update().times(1);
        let risk_exits_dep = risk_exits_dep.with(always(), eq_stop_loss, eq_take_profit, eq_max_hold_time, eq_risk_idx);
        let risk_exits_dep = risk_exits_dep.in_sequence(&mut sequence);
        risk_exits_dep.return_const(());

        let eq_signal_idx = eq(0);

        let signal_exits_dep = mock_deps.expect_signal_exits_update().times(1);
        let signal_exits_dep = signal_exits_dep.with(always(), eq_signal_idx);
        let signal_exits_dep = signal_exits_dep.in_sequence(&mut sequence);
        signal_exits_dep.return_const(());

        let eq_qty = eq(qty);
        let eq_open_idx = eq(0);

        let try_open_lot_dep = mock_deps.expect_try_open_lot().times(1);
        let try_open_lot_dep = try_open_lot_dep.with(always(), eq_qty, eq_open_idx);
        let try_open_lot_dep = try_open_lot_dep.in_sequence(&mut sequence);
        try_open_lot_dep.return_const(());

        let eq_equity_idx = eq(0);

        let update_equity_dep = mock_deps.expect_update_equity().times(1);
        let update_equity_dep = update_equity_dep.with(always(), always(), eq_equity_idx);
        let update_equity_dep = update_equity_dep.in_sequence(&mut sequence);
        update_equity_dep.return_const(());

        let results_dep = mock_deps.expect_results().times(1);
        let results_dep = results_dep.with(always(), always());
        let results_dep = results_dep.in_sequence(&mut sequence);
        results_dep.returning(|state, _| {
            let n_bars = state.equity.len();
            BacktestResults {
                metrics: HashMap::new(),
                is_invalid: false,
                n_bars,
                final_state: state
            }
        });

        let results = _backtest(&mock_deps, net_signals, qty, stop_loss, take_profit, max_hold_time, &schema, &close_prices);

        assert_eq!(results.n_bars, 1);
    }
}
