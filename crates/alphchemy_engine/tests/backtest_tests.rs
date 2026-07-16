use alphchemy_engine::experiment::strategy::NetSignals;
use alphchemy_engine::experiment::backtest::{BacktestSchema, BacktestMetric, backtest};
use alphchemy_engine::experiment::tojson::backtest_results_json;

fn default_backtest_schema() -> BacktestSchema {
    BacktestSchema {
        start_offset: 0,
        start_balance: 10000.0,
        delay: 0,
        metrics: vec![BacktestMetric::ExcessSharpe]
    }
}

fn signals_from(entries: Vec<bool>, exits: Vec<bool>) -> Vec<NetSignals> {
    assert_eq!(entries.len(), exits.len());
    entries.into_iter().zip(exits).map(|(entry, exit)| {
        NetSignals { entry, exit }
    }).collect()
}

#[test]
fn test_take_profit_exit() {
    let close_prices = vec![100.0, 100.0, 110.0, 110.0, 110.0];
    let entries = vec![true, false, false, false, false];
    let exits = vec![false, false, false, false, false];
    let signals = signals_from(entries, exits);

    let results = backtest(
        signals,
        0.1,
        0.05,
        0.05,
        50,
        &default_backtest_schema(),
        &close_prices
    );

    assert!(results.final_state.take_profit_exits > 0);
}

#[test]
fn test_stop_loss_exit() {
    let close_prices = vec![100.0, 100.0, 90.0, 90.0, 90.0];
    let entries = vec![true, false, false, false, false];
    let exits = vec![false, false, false, false, false];
    let signals = signals_from(entries, exits);

    let results = backtest(
        signals,
        0.1,
        0.05,
        0.5,
        50,
        &default_backtest_schema(),
        &close_prices
    );

    assert!(results.final_state.stop_loss_exits > 0);
}

#[test]
fn test_max_hold_exit() {
    let close_prices = vec![100.0, 100.0, 100.0, 100.0, 100.0];
    let entries = vec![true, false, false, false, false];
    let exits = vec![false, false, false, false, false];
    let signals = signals_from(entries, exits);

    let results = backtest(
        signals,
        0.1,
        0.5,
        0.5,
        2,
        &default_backtest_schema(),
        &close_prices
    );

    assert!(results.final_state.max_hold_exits > 0);
}

#[test]
fn test_signal_exit() {
    let close_prices = vec![100.0, 100.0, 100.0, 100.0, 100.0];
    let entries = vec![true, false, false, false, false];
    let exits = vec![false, false, true, false, false];
    let signals = signals_from(entries, exits);

    let results = backtest(
        signals,
        0.1,
        0.5,
        0.5,
        50,
        &default_backtest_schema(),
        &close_prices
    );

    assert!(results.final_state.signal_exits > 0);
}

#[test]
fn test_no_exits_is_invalid() {
    let n_bars = 20;
    let close_prices = vec![100.0; n_bars];
    let entries = vec![true; n_bars];
    let exits = vec![false; n_bars];
    let signals = signals_from(entries, exits);

    let results = backtest(
        signals,
        0.1,
        0.5,
        0.5,
        100,
        &default_backtest_schema(),
        &close_prices
    );

    assert!(results.is_invalid);
}

#[test]
fn test_n_bars_excludes_start_offset() {
    let n_bars = 5;
    let close_prices = vec![100.0; n_bars];
    let entries = vec![false; n_bars];
    let exits = vec![false; n_bars];
    let signals = signals_from(entries, exits);
    let mut schema = default_backtest_schema();
    schema.start_offset = 2;

    let results = backtest(signals, 0.1, 0.5, 0.5, 100, &schema, &close_prices);
    let results_json = backtest_results_json(&results);

    assert_eq!(results.n_bars, 3);
    assert_eq!(results_json["n_bars"], 3);
}

#[test]
fn test_n_bars_saturates_at_zero() {
    let n_bars = 2;
    let close_prices = vec![100.0; n_bars];
    let entries = vec![false; n_bars];
    let exits = vec![false; n_bars];
    let signals = signals_from(entries, exits);
    let mut schema = default_backtest_schema();
    schema.start_offset = 3;

    let results = backtest(signals, 0.1, 0.5, 0.5, 100, &schema, &close_prices);

    assert_eq!(results.n_bars, 0);
}

#[test]
fn test_balance_after_profitable_trade() {
    let close_prices = vec![100.0, 100.0, 200.0, 200.0];
    let entries = vec![true, false, false, false];
    let exits = vec![false, false, false, false];
    let signals = signals_from(entries, exits);

    let schema = BacktestSchema {
        start_offset: 0,
        start_balance: 10000.0,
        delay: 0,
        metrics: vec![BacktestMetric::ExcessSharpe]
    };

    let results = backtest(
        signals,
        1.0,
        0.5,
        0.5,
        50,
        &schema,
        &close_prices
    );

    assert!(results.final_state.balance > 10000.0);
}

#[test]
fn test_single_lot_blocks_concurrent_entry() {
    let close_prices = vec![100.0, 100.0, 100.0, 100.0];
    let entries = vec![true, true, true, false];
    let exits = vec![false, false, false, false];
    let signals = signals_from(entries, exits);

    let results = backtest(
        signals,
        0.1,
        0.5,
        0.5,
        100,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.entries, 1);
    assert!(results.final_state.lot.is_some());
}
