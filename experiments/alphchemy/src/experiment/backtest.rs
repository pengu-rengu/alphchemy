use serde::Deserialize;
use serde_json::Value;
use crate::utils::{parse_json, std_dev};
use super::strategy::{NetSignals, EntrySchema, ExitSchema};

#[derive(Clone, Debug, Deserialize)]
pub struct BacktestSchema {
    pub start_offset: usize,
    pub start_balance: f64,
    pub delay: usize
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
    pub enter_idx: usize,
    pub schema_id: String
}

impl Lot {
    fn exit_conds(&self, exit_schema: &ExitSchema, current_close: f64, idx: usize) -> ExitConds {
        let take_profit_price = self.enter_price * (1.0 + exit_schema.take_profit);
        let sl_factor = 1.0 - exit_schema.stop_loss;
        let stop_loss_price = self.enter_price * sl_factor;
        let hold_time = idx - self.enter_idx;

        ExitConds {
            take_profit: current_close > take_profit_price,
            stop_loss: current_close < stop_loss_price,
            max_hold: hold_time >= exit_schema.max_hold_time
        }
    }

    fn matches_exit(&self, exit_schema: &ExitSchema) -> bool {
        exit_schema.entry_ids.contains(&self.schema_id)
    }
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

    fn close_lot(&mut self, lot: &Lot, idx: usize) {
        self.balance += self.close_prices[idx] * lot.size;

        self.hold_times.push(idx - lot.enter_idx);
        self.total_exits += 1;
    }

    fn risk_exits_update(&mut self, exit_schema: &ExitSchema, idx: usize) {
        let curr_close = self.close_prices[idx];

        let Some(lot_ref) = &self.lot else { return; };
        if !lot_ref.matches_exit(exit_schema) {
            return;
        }

        let conds = lot_ref.exit_conds(exit_schema, curr_close, idx);
        if !conds.any() {
            return;
        }

        let lot = self.lot.take().unwrap();
        self.close_lot(&lot, idx);

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

    fn signal_exits_update(&mut self, exit_schema: &ExitSchema, idx: usize) {
        let has_signal = self.net_signals[idx].exit_signal(&exit_schema.id);
        if !has_signal {
            return;
        }

        let Some(lot_ref) = &self.lot else { return; };
        if !lot_ref.matches_exit(exit_schema) {
            return;
        }

        let lot = self.lot.take().unwrap();
        self.close_lot(&lot, idx);
        self.signal_exits += 1;
    }

    fn exit_update(&mut self, exit_schemas: &[ExitSchema], idx: usize) {

        for exit_schema in exit_schemas {
            self.risk_exits_update(exit_schema, idx);
            self.signal_exits_update(exit_schema, idx);
        }
    }

    fn try_open_lot(&mut self, entry_schema: &EntrySchema, idx: usize) {
        if self.lot.is_some() {
            return;
        }

        if !self.net_signals[idx].entry_signal(&entry_schema.id) {
            return;
        }

        let curr_close = self.close_prices[idx];
        let cost = entry_schema.qty * curr_close;

        if cost > self.balance {
            return;
        }

        let lot = Lot {
            enter_price: curr_close,
            size: entry_schema.qty,
            enter_idx: idx,
            schema_id: entry_schema.id.clone()
        };
        self.balance -= cost;

        self.lot = Some(lot);
        self.entries += 1;
    }

    fn entry_update(&mut self, entry_schemas: &[EntrySchema], idx: usize) {
        for entry_schema in entry_schemas {
            self.try_open_lot(entry_schema, idx);
        }
    }

    fn update_equity(&mut self, schema: &BacktestSchema, idx: usize) {
        let curr_close = self.close_prices[idx];

        let market_value = match &self.lot {
            Some(lot) => lot.size * curr_close,
            None => 0.0
        };

        let equity_idx = idx - schema.start_offset;
        self.equity[equity_idx] = self.balance + market_value;
    }

    fn backtest_iter(&mut self, entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema], schema: &BacktestSchema, idx: usize) {
        self.exit_update(exit_schemas, idx);
        self.entry_update(entry_schemas, idx);
        self.update_equity(schema, idx);
    }

    fn results(self, schema: &BacktestSchema) -> BacktestResults {
        let neg_equity = self.equity.iter().any(|&value| value < 0.0);
        let no_exits = self.total_exits == 0;

        if neg_equity || no_exits {
            return BacktestResults {
                excess_sharpe: 0.0,
                mean_hold_time: 0.0,
                std_hold_time: 0.0,
                is_invalid: true,
                final_state: self
            };
        }

        let close_slice = &self.close_prices[schema.start_offset..];
        let close_sharpe = sharpe(close_slice);
        let equity_sharpe = sharpe(&self.equity);
        let excess_sharpe = equity_sharpe - close_sharpe;

        let count = self.hold_times.len() as f64;
        let mean_hold_time = self.hold_times.iter().sum::<usize>() as f64 / count;
        let hold_times_f64: Vec<f64> = self.hold_times.iter().map(|&value| value as f64).collect();
        let std_hold_time = std_dev(&hold_times_f64);

        BacktestResults {
            excess_sharpe,
            mean_hold_time,
            std_hold_time,
            is_invalid: false,
            final_state: self
        }
    }
}

#[derive(Clone, Debug)]
pub struct BacktestResults {
    pub excess_sharpe: f64,
    pub mean_hold_time: f64,
    pub std_hold_time: f64,
    pub is_invalid: bool,
    pub final_state: BacktestState
}

fn log_returns(values: &[f64]) -> Vec<f64> {
    if values.len() < 2 {
        return Vec::new();
    }
    let mut returns = Vec::with_capacity(values.len() - 1);
    for i in 1..values.len() {
        returns.push((values[i] / values[i - 1]).ln());
    }
    returns
}

fn sharpe(values: &[f64]) -> f64 {
    let returns = log_returns(values);
    if returns.len() < 2 {
        return 0.0;
    }
    let mean = returns.iter().sum::<f64>() / returns.len() as f64;
    let std = std_dev(&returns);
    if std == 0.0 {
        return 0.0;
    }
    mean / std
}

pub fn backtest(net_signals: Vec<NetSignals>, entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema], schema: &BacktestSchema, close_prices: &[f64]) -> BacktestResults {
    let mut state = BacktestState::new(net_signals, schema, close_prices);
    let close_len = state.close_prices.len();

    for i in schema.start_offset..close_len {
        state.backtest_iter(entry_schemas, exit_schemas, schema, i);
    }

    state.results(schema)
}

pub fn parse_backtest_schema(json: &Value) -> Result<BacktestSchema, String> {
    let backtest_schema = parse_json::<BacktestSchema>(json)?;

    if backtest_schema.start_balance <= 0.0 { return Err("start_balance must be > 0.0".to_string()); }

    Ok(backtest_schema)
}
