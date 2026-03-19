use serde::Deserialize;
use serde_json::Value;
use crate::utils::parse_json;
use super::strategy::{NetworkSignal, EntrySchema, ExitSchema};

#[derive(Clone, Debug, Deserialize)]
pub struct BacktestSchema {
    pub start_offset: usize,
    pub start_balance: f64,
    pub delay: usize
}

struct ExitConds {
    tp: bool,
    sl: bool,
    hold: bool
}

impl ExitConds {
    fn any(&self) -> bool {
        self.tp || self.sl || self.hold
    }
}

#[derive(Clone, Debug)]
pub struct Lot {
    pub enter_price: f64,
    pub size: f64,
    pub enter_idx: usize,
    pub schema_idx: usize
}

impl Lot {
    fn exit_conds(&self, exit_schema: &ExitSchema, current_close: f64, idx: usize) -> ExitConds {
        let take_profit_price = self.enter_price * (1.0 + exit_schema.take_profit);
        let stop_loss_price = self.enter_price * (1.0 - exit_schema.stop_loss);
        let hold_time = idx - self.enter_idx;

        ExitConds {
            tp: current_close > take_profit_price,
            sl: current_close < stop_loss_price,
            hold: hold_time >= exit_schema.max_hold_time
        }
    }
}

#[derive(Clone, Debug)]
pub struct BacktestState {
    pub net_signals: Vec<NetworkSignal>,
    pub close_prices: Vec<f64>,
    pub balance: f64,
    pub equity: Vec<f64>,
    pub lots: Vec<Lot>,
    pub entries: usize,
    pub total_exits: usize,
    pub signal_exits: usize,
    pub take_profit_exits: usize,
    pub stop_loss_exits: usize,
    pub max_hold_time_exits: usize,
    pub hold_times: Vec<usize>
}

impl BacktestState {
    fn new(
        net_signals: Vec<NetworkSignal>,
        schema: &BacktestSchema,
        close_prices: &[f64]
    ) -> Self {
        let equity_len =  close_prices.len() - schema.start_offset;
        
        BacktestState {
            net_signals,
            close_prices: close_prices.to_vec(),
            balance: schema.start_balance,
            equity: vec![0.0; equity_len],
            lots: Vec::new(),
            entries: 0,
            total_exits: 0,
            signal_exits: 0,
            take_profit_exits: 0,
            stop_loss_exits: 0,
            max_hold_time_exits: 0,
            hold_times: Vec::new()
        }
    }

    fn close_lot(&mut self, lot: &Lot, current_close: f64, idx: usize) {
        let diff = current_close - lot.enter_price;
        self.balance += diff * lot.size;

        let hold_time = idx - lot.enter_idx;
        self.hold_times.push(hold_time);
        self.total_exits += 1;
    }

    fn process_sl_tp_hold_exits(&mut self, exit_schema: &ExitSchema, current_close: f64, idx: usize) {
        let mut i = 0;

        while i < self.lots.len() {
            let lot = &self.lots[i];

            if !exit_schema.entry_indices.contains(&lot.schema_idx) {
                i += 1;
                continue;
            }

            let conds = lot.exit_conds(exit_schema, current_close, idx);

            if conds.any() {
                let lot = self.lots.remove(i);
                self.close_lot(&lot, current_close, idx);

                if conds.tp { self.take_profit_exits += 1; }
                if conds.sl { self.stop_loss_exits += 1; }
                if conds.hold { self.max_hold_time_exits += 1; }
            } else {
                i += 1;
            }
        }
    }

    fn signal_exits_update(
        &mut self,
        exit_schema: &ExitSchema,
        current_close: f64,
        idx: usize,
        exit_i: usize
    ) {
        if !self.net_signals[idx].exits[exit_i] {
            return;
        }

        let mut i = 0;
        while i < self.lots.len() {
            if !exit_schema.entry_indices.contains(&self.lots[i].schema_idx) {
                i += 1;
                continue;
            }

            let lot = self.lots.remove(i);
            self.close_lot(&lot, current_close, idx);
            self.signal_exits += 1;
        }
    }

    fn exit_update(&mut self, exit_schemas: &[ExitSchema], idx: usize) {
        let current_close = self.close_prices[idx];

        for (exit_i, exit_schema) in exit_schemas.iter().enumerate() {
            self.process_sl_tp_hold_exits(exit_schema, current_close, idx);
            self.signal_exits_update(exit_schema, current_close, idx, exit_i);
        }
    }

    fn try_open_lot(
        &mut self,
        entry_schema: &EntrySchema,
        entry_i: usize,
        idx: usize
    ) -> bool {
        if !self.net_signals[idx].entries[entry_i] {
            return false;
        }

        let is_entry_lot_fn = |lot: &&Lot| lot.schema_idx == entry_i;
        let count = self.lots.iter().filter(is_entry_lot_fn).count();
        if count >= entry_schema.max_positions {
            return false;
        }

        if self.balance <= 0.0 {
            return false;
        }

        let alloc_amount = self.balance * entry_schema.position_size;
        if alloc_amount <= 0.0 {
            return false;
        }

        let curr_close = self.close_prices[idx];

        let size = alloc_amount / curr_close;
        self.lots.push(Lot {
            enter_price: curr_close,
            size,
            enter_idx: idx,
            schema_idx: entry_i
        });
        self.entries += 1;
        true
    }

    fn entry_processing(&mut self, entry_schemas: &[EntrySchema], idx: usize) {
        for (entry_i, entry_schema) in entry_schemas.iter().enumerate() {
            self.try_open_lot(entry_schema, entry_i, idx);
        }
    }

    fn update_equity(&mut self, schema: &BacktestSchema, idx: usize) {
        let equity_idx = idx - schema.start_offset;
        let curr_close = self.close_prices[idx];

        let lot_equity_fn = |lot: &Lot| {
            let diff = curr_close - lot.enter_price;
            lot.size * diff
        };

        self.equity[equity_idx] = self.lots.iter().map(lot_equity_fn).sum();
    }

    fn backtest_iter(
        &mut self,
        entry_schemas: &[EntrySchema],
        exit_schemas: &[ExitSchema],
        schema: &BacktestSchema,
        idx: usize
    ) {
        self.exit_update(exit_schemas, idx);
        self.entry_processing(entry_schemas, idx);
        self.update_equity(schema, idx);
    }

    fn results(self, schema: &BacktestSchema) -> BacktestResults {
        let neg_equity = self.equity.iter().any(|&e| e <= 0.0);
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

        let n = self.hold_times.len() as f64;
        let mean_hold_time = self.hold_times.iter().sum::<usize>() as f64 / n;
        let std_hold_time = if n > 1.0 {

            let variance = self.hold_times.iter()
                .map(|&t| (t as f64 - mean_hold_time).powi(2))
                .sum::<f64>() / (n - 1.0);
            let s = variance.sqrt();
            if s.is_nan() { 0.0 } else { s }

        } else {
            0.0
        };

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

    let n: f64 = returns.len() as f64;
    let mean = returns.iter().sum::<f64>() / n;
    let variance = returns.iter().map(|r| (r - mean).powi(2)).sum::<f64>() / (n - 1.0);
    let std = variance.sqrt();

    if std == 0.0 {
        return 0.0;
    }

    mean / std
}

pub fn backtest(
    net_signals: Vec<NetworkSignal>,
    entry_schemas: &[EntrySchema],
    exit_schemas: &[ExitSchema],
    schema: &BacktestSchema,
    close_prices: &[f64]
) -> BacktestResults {
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
