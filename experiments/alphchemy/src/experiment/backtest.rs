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
    let mean = returns.iter().sum::<f64>() / len as f64;
    let std = deps.std_dev(&returns);
    if std == 0.0 {
        return 0.0;
    }
    mean / std
}

#[allow(clippy::too_many_arguments)]
fn _backtest<D>(deps: &D, net_signals: Vec<NetSignals>, qty: f64, stop_loss: f64, take_profit: f64, max_hold_time: usize, schema: &BacktestSchema, close_prices: &[f64]) -> BacktestResults where D: BacktestDeps {
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
