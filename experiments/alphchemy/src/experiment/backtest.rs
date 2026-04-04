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
        let tp_or_sl = self.take_profit || self.stop_loss;
        tp_or_sl || self.max_hold
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

    fn matches_entry(&self, entry_schema: &EntrySchema) -> bool {
        let entry_id = entry_schema.id.as_str();
        self.schema_id == entry_id
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
    pub lots: Vec<Lot>,
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
            lots: Vec::new(),
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
        let diff = self.close_prices[idx] - lot.enter_price;
        let pnl = diff * lot.size;
        self.balance += pnl;

        self.hold_times.push(idx - lot.enter_idx);
        self.total_exits += 1;
    }

    fn risk_exits_update(&mut self, exit_schema: &ExitSchema, idx: usize) {
        let curr_close = self.close_prices[idx];
        let mut i = 0;

        while i < self.lots.len() {
            let lot = &self.lots[i];

            let matches_exit = lot.matches_exit(exit_schema);
            if !matches_exit {
                i += 1;
                continue;
            }

            let conds = lot.exit_conds(exit_schema, curr_close, idx);

            if conds.any() {
                let lot = self.lots.remove(i);
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
            } else {
                i += 1;
            }
        }
    }

    fn signal_exits_update(&mut self, exit_schema: &ExitSchema, schema_idx: usize, idx: usize) {
        if !self.net_signals[idx].exits[schema_idx] {
            return;
        }

        let mut i = 0;

        while i < self.lots.len() {
            let matches_exit = self.lots[i].matches_exit(exit_schema);
            if !matches_exit {
                i += 1;
                continue;
            }

            let lot = self.lots.remove(i);
            self.close_lot(&lot, idx);
            self.signal_exits += 1;
        }
    }

    fn exit_update(&mut self, exit_schemas: &[ExitSchema], idx: usize) {

        for (schema_idx, exit_schema) in exit_schemas.iter().enumerate() {
            self.risk_exits_update(exit_schema, idx);
            self.signal_exits_update(exit_schema, schema_idx, idx);
        }
    }

    fn try_open_lot(&mut self, entry_schema: &EntrySchema, global_max_positions: usize, schema_idx: usize, idx: usize) -> bool {
        if !self.net_signals[idx].entries[schema_idx] {
            return false;
        }

        let total_count = self.lots.len();
        if total_count >= global_max_positions {
            return false;
        }

        let matches_entry = |lot: &&Lot| lot.matches_entry(entry_schema);
        let count = self.lots.iter().filter(matches_entry).count();
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
        let schema_id = entry_schema.id.clone();
        self.lots.push(Lot {
            enter_price: curr_close,
            size,
            enter_idx: idx,
            schema_id
        });
        self.entries += 1;
        true
    }

    fn entry_update(&mut self, entry_schemas: &[EntrySchema], global_max_positions: usize, idx: usize) {
        for (entry_i, entry_schema) in entry_schemas.iter().enumerate() {
            self.try_open_lot(entry_schema, global_max_positions, entry_i, idx);
        }
    }

    fn update_equity(&mut self, schema: &BacktestSchema, idx: usize) {
        let curr_close = self.close_prices[idx];
        
        let lot_unrealized_fn = |lot: &Lot| {
            let diff = curr_close - lot.enter_price;
            lot.size * diff
        };
        let unrealized = self.lots.iter().map(lot_unrealized_fn).sum::<f64>();

        let equity_idx = idx - schema.start_offset;
        self.equity[equity_idx] = self.balance + unrealized;
    }

    fn backtest_iter(&mut self, entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema], global_max_positions: usize, schema: &BacktestSchema, idx: usize) {
        self.exit_update(exit_schemas, idx);
        self.entry_update(entry_schemas, global_max_positions, idx);
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

pub fn backtest(net_signals: Vec<NetSignals>, entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema], global_max_positions: usize, schema: &BacktestSchema, close_prices: &[f64]) -> BacktestResults {
    let mut state = BacktestState::new(net_signals, schema, close_prices);
    let close_len = state.close_prices.len();

    for i in schema.start_offset..close_len {
        state.backtest_iter(entry_schemas, exit_schemas, global_max_positions, schema, i);
    }

    state.results(schema)
}

pub fn parse_backtest_schema(json: &Value) -> Result<BacktestSchema, String> {
    let backtest_schema = parse_json::<BacktestSchema>(json)?;

    if backtest_schema.start_balance <= 0.0 { return Err("start_balance must be > 0.0".to_string()); }

    Ok(backtest_schema)
}
