use super::strategy::NetworkSignal;

#[derive(Clone, Debug)]
pub struct BacktestSchema {
    pub start_offset: usize,
    pub start_balance: f64,
    pub alloc_size: f64,
    pub delay: usize
}

#[derive(Clone, Debug)]
pub struct ExitConds {
    pub exit_signal: bool,
    pub take_profit: bool,
    pub stop_loss: bool,
    pub max_hold_time: bool
}

#[derive(Clone, Debug)]
pub struct BacktestState {
    pub net_signals: Vec<NetworkSignal>,
    pub close_prices: Vec<f64>,
    pub balance: f64,
    pub equity: Vec<f64>,
    pub enter_price: f64,
    pub enter_idx: i64,
    pub enter_size: f64,
    pub entries: usize,
    pub total_exits: usize,
    pub signal_exits: usize,
    pub take_profit_exits: usize,
    pub stop_loss_exits: usize,
    pub max_hold_time_exits: usize,
    pub hold_times: Vec<usize>
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

    if returns.is_empty() {
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

fn entry_update(schema: &BacktestSchema, state: &mut BacktestState, idx: usize) {
    if !state.net_signals[idx].entry {
        return;
    }

    let current_close = state.close_prices[idx];
    state.enter_price = current_close;

    let alloc_amount = state.balance * schema.alloc_size;
    state.enter_size = alloc_amount / current_close;

    state.entries += 1;
    state.enter_idx = idx as i64;
}

fn exit_conds(
    stop_loss: f64,
    take_profit: f64,
    max_hold_time: usize,
    state: &BacktestState,
    idx: usize
) -> ExitConds {
    let current_close = state.close_prices[idx];
    let enter_price = state.enter_price;

    let take_profit_ratio = 1.0 + take_profit;
    let take_profit_price = enter_price * take_profit_ratio;
    let take_profit_signal = current_close > take_profit_price;

    let stop_loss_ratio = 1.0 - stop_loss;
    let stop_loss_price = enter_price * stop_loss_ratio;
    let stop_loss_signal = current_close < stop_loss_price;

    let indices_since_enter = idx as i64 - state.enter_idx;
    let hold_time_signal = indices_since_enter >= max_hold_time as i64;

    ExitConds {
        exit_signal: state.net_signals[idx].exit,
        take_profit: take_profit_signal,
        stop_loss: stop_loss_signal,
        max_hold_time: hold_time_signal
    }
}

fn should_exit(conds: &ExitConds) -> bool {
    conds.exit_signal || conds.stop_loss || conds.take_profit || conds.max_hold_time
}

fn inc_exit_counts(state: &mut BacktestState, conds: &ExitConds) {
    state.total_exits += 1;

    if conds.exit_signal {
        state.signal_exits += 1;
    }
    if conds.take_profit {
        state.take_profit_exits += 1;
    }
    if conds.stop_loss {
        state.stop_loss_exits += 1;
    }
    if conds.max_hold_time {
        state.max_hold_time_exits += 1;
    }
}

fn exit_update(
    stop_loss: f64,
    take_profit: f64,
    max_hold_time: usize,
    state: &mut BacktestState,
    idx: usize
) {
    let conds = exit_conds(stop_loss, take_profit, max_hold_time, state, idx);

    if !should_exit(&conds) {
        return;
    }

    let diff = state.close_prices[idx] - state.enter_price;
    state.balance += diff * state.enter_size;
    state.enter_price = -1.0;

    let hold_time = (idx as i64 - state.enter_idx) as usize;
    state.hold_times.push(hold_time);

    inc_exit_counts(state, &conds);
}

fn update_equity(schema: &BacktestSchema, state: &mut BacktestState, idx: usize) {
    let enter_price = state.enter_price;
    let balance = state.balance;
    let equity_idx = idx - schema.start_offset;
    let mut equity_value = balance;

    if enter_price > 0.0 {
        let diff = state.close_prices[idx] - enter_price;
        let unrealized = state.enter_size * diff;
        equity_value += unrealized;
    }

    state.equity[equity_idx] = equity_value;
}

fn initial_backtest_state(
    net_signals: Vec<NetworkSignal>,
    schema: &BacktestSchema,
    close_prices: &[f64]
) -> BacktestState {
    let data_len = close_prices.len();
    let equity_len = data_len - schema.start_offset;

    BacktestState {
        net_signals,
        close_prices: close_prices.to_vec(),
        balance: schema.start_balance,
        equity: vec![0.0; equity_len],
        enter_price: -1.0,
        enter_idx: -1,
        enter_size: -1.0,
        entries: 0,
        total_exits: 0,
        signal_exits: 0,
        take_profit_exits: 0,
        stop_loss_exits: 0,
        max_hold_time_exits: 0,
        hold_times: Vec::new()
    }
}

fn backtest_iter(
    stop_loss: f64,
    take_profit: f64,
    max_hold_time: usize,
    schema: &BacktestSchema,
    state: &mut BacktestState,
    idx: usize
) {
    if state.enter_price < 0.0 {
        entry_update(schema, state, idx);
    } else {
        exit_update(stop_loss, take_profit, max_hold_time, state, idx);
    }

    update_equity(schema, state, idx);
}

fn backtest_results(state: BacktestState, schema: &BacktestSchema) -> BacktestResults {
    let neg_equity = state.equity.iter().any(|&e| e <= 0.0);
    let no_exits = state.total_exits == 0;

    if neg_equity || no_exits {
        return BacktestResults {
            excess_sharpe: 0.0,
            mean_hold_time: 0.0,
            std_hold_time: 0.0,
            is_invalid: true,
            final_state: state
        };
    }

    let close_slice = &state.close_prices[schema.start_offset..];
    let close_sharpe = sharpe(close_slice);
    let equity_sharpe = sharpe(&state.equity);
    let excess_sharpe = equity_sharpe - close_sharpe;

    let n = state.hold_times.len() as f64;
    let mean_hold_time = state.hold_times.iter().sum::<usize>() as f64 / n;
    let std_hold_time = if n > 1.0 {
        let variance = state.hold_times.iter()
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
        final_state: state
    }
}

pub fn backtest(
    net_signals: Vec<NetworkSignal>,
    stop_loss: f64,
    take_profit: f64,
    max_hold_time: usize,
    schema: &BacktestSchema,
    close_prices: &[f64]
) -> BacktestResults {
    let mut state = initial_backtest_state(net_signals, schema, close_prices);
    let close_len = state.close_prices.len();

    for i in (schema.start_offset + 1)..close_len {
        backtest_iter(stop_loss, take_profit, max_hold_time, schema, &mut state, i);
    }

    backtest_results(state, schema)
}
