use alphchemy::experiment::strategy::{NetSignals, EntrySchema, ExitSchema};
use alphchemy::experiment::backtest::{BacktestSchema, backtest};
use alphchemy::network::network::{Anchor, NodePtr};

fn default_node_ptr() -> NodePtr {
    NodePtr { anchor: Anchor::FromEnd, idx: 0 }
}

fn default_entry_schema() -> EntrySchema {
    EntrySchema {
        node_ptr: default_node_ptr(),
        position_size: 0.1,
        max_positions: 3
    }
}

fn default_backtest_schema() -> BacktestSchema {
    BacktestSchema {
        start_offset: 0,
        start_balance: 10000.0,
        delay: 0
    }
}

fn signals_from(entries: Vec<bool>, exits: Vec<bool>) -> Vec<NetSignals> {
    assert_eq!(entries.len(), exits.len());
    entries.into_iter().zip(exits).map(|(entry, exit)| {
        NetSignals {
            entries: vec![entry],
            exits: vec![exit]
        }
    }).collect()
}

#[test]
fn test_take_profit_exit() {
    let close_prices = vec![100.0, 100.0, 110.0, 110.0, 110.0];
    let entries = vec![true, false, false, false, false];
    let exits = vec![false, false, false, false, false];
    let signals = signals_from(entries, exits);

    let exit_schema = ExitSchema {
        node_ptr: default_node_ptr(),
        entry_indices: vec![0],
        stop_loss: 0.05,
        take_profit: 0.05,
        max_hold_time: 50
    };

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
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

    let exit_schema = ExitSchema {
        node_ptr: default_node_ptr(),
        entry_indices: vec![0],
        stop_loss: 0.05,
        take_profit: 0.5,
        max_hold_time: 50
    };

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
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

    let exit_schema = ExitSchema {
        node_ptr: default_node_ptr(),
        entry_indices: vec![0],
        stop_loss: 0.5,
        take_profit: 0.5,
        max_hold_time: 2
    };

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
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

    let exit_schema = ExitSchema {
        node_ptr: default_node_ptr(),
        entry_indices: vec![0],
        stop_loss: 0.5,
        take_profit: 0.5,
        max_hold_time: 50
    };

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
        &default_backtest_schema(),
        &close_prices
    );

    assert!(results.final_state.signal_exits > 0);
}

#[test]
fn test_max_positions_respected() {
    let n_bars = 10;
    let close_prices = vec![100.0; n_bars];
    let entries = vec![true; n_bars];
    let exits = vec![false; n_bars];
    let signals = signals_from(entries, exits);

    let entry_schema = EntrySchema {
        node_ptr: default_node_ptr(),
        position_size: 0.1,
        max_positions: 2
    };

    let exit_schema = ExitSchema {
        node_ptr: default_node_ptr(),
        entry_indices: vec![0],
        stop_loss: 0.5,
        take_profit: 0.5,
        max_hold_time: 100
    };

    let results = backtest(
        signals,
        &[entry_schema],
        &[exit_schema],
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.entries, 2);
}

#[test]
fn test_no_exits_is_invalid() {
    let n_bars = 20;
    let close_prices = vec![100.0; n_bars];
    let entries = vec![true; n_bars];
    let exits = vec![false; n_bars];
    let signals = signals_from(entries, exits);

    let exit_schema = ExitSchema {
        node_ptr: default_node_ptr(),
        entry_indices: vec![0],
        stop_loss: 0.5,
        take_profit: 0.5,
        max_hold_time: 100
    };

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
        &default_backtest_schema(),
        &close_prices
    );

    assert!(results.is_invalid);
}

#[test]
fn test_negative_equity_is_invalid() {
    let mut close_prices = vec![100.0];
    for _ in 0..20 {
        let last = *close_prices.last().unwrap();
        close_prices.push(last * 0.8);
    }

    let n_bars = close_prices.len();
    let mut entries = vec![true; n_bars];
    entries[0] = true;
    let exits = vec![false; n_bars];
    let signals = signals_from(entries, exits);

    let entry_schema = EntrySchema {
        node_ptr: default_node_ptr(),
        position_size: 1.0,
        max_positions: 10
    };

    let exit_schema = ExitSchema {
        node_ptr: default_node_ptr(),
        entry_indices: vec![0],
        stop_loss: 0.99,
        take_profit: 0.99,
        max_hold_time: 2
    };

    let results = backtest(
        signals,
        &[entry_schema],
        &[exit_schema],
        &default_backtest_schema(),
        &close_prices
    );

    assert!(results.is_invalid);
}

#[test]
fn test_balance_after_profitable_trade() {
    let close_prices = vec![100.0, 100.0, 200.0, 200.0];
    let entries = vec![true, false, false, false];
    let exits = vec![false, false, false, false];
    let signals = signals_from(entries, exits);

    let entry_schema = EntrySchema {
        node_ptr: default_node_ptr(),
        position_size: 1.0,
        max_positions: 1
    };

    let exit_schema = ExitSchema {
        node_ptr: default_node_ptr(),
        entry_indices: vec![0],
        stop_loss: 0.5,
        take_profit: 0.5,
        max_hold_time: 50
    };

    let schema = BacktestSchema {
        start_offset: 0,
        start_balance: 10000.0,
        delay: 0
    };

    let results = backtest(
        signals,
        &[entry_schema],
        &[exit_schema],
        &schema,
        &close_prices
    );

    assert!(results.final_state.balance > 10000.0);
}
