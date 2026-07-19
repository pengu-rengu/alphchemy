use alphchemy_engine::actions::logic_actions::LogicActions;
use alphchemy_engine::experiment::strategy::NetSignals;
use alphchemy_engine::experiment::strategy::Strategy;
use alphchemy_engine::experiment::backtest::{BacktestSchema, BacktestMetric, backtest};
use alphchemy_engine::experiment::tojson::backtest_results_json;
use alphchemy_engine::network::logic_net::{Gate, LogicNet, LogicPenalties};
use alphchemy_engine::network::network::{Anchor, NodePtr};
use alphchemy_engine::optimizer::genetic::GeneticOpt;
use alphchemy_engine::optimizer::optimizer::StopConds;
use std::collections::HashMap;

fn default_strategy() -> Strategy<LogicNet, LogicPenalties, LogicActions> {
    Strategy {
        base_net: LogicNet {
            nodes: Vec::new(),
            default_value: false
        },
        feats: Vec::new(),
        actions: LogicActions {
            meta_actions: HashMap::new(),
            thresholds: HashMap::new(),
            feat_order: Vec::new(),
            n_thresholds: 1,
            allow_recurrence: false,
            allowed_gates: vec![Gate::And]
        },
        penalties: LogicPenalties {
            node: 0.0,
            input: 0.0,
            gate: 0.0,
            recurrence: 0.0,
            feedforward: 0.0,
            used_feat: 0.0,
            unused_feat: 0.0
        },
        stop_conds: StopConds {
            max_iters: 1,
            train_patience: 1,
            val_patience: 1
        },
        opt: GeneticOpt {
            pop_size: 1,
            seq_len: 1,
            n_elites: 0,
            mut_rate: 0.0,
            cross_rate: 0.0,
            tourn_size: 1,
            objectives: Vec::new(),
            random_seed: Some(1)
        },
        entry_ptr: NodePtr { anchor: Anchor::FromStart, offset: 0 },
        exit_ptr: NodePtr { anchor: Anchor::FromStart, offset: 0 },
        strong_entry: false,
        strong_exit: false,
        stop_loss: 0.5,
        take_profit: 0.5,
        max_hold_time: 100,
        qty: 0.1
    }
}

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
    let mut strategy = default_strategy();
    strategy.stop_loss = 0.05;
    strategy.take_profit = 0.05;
    strategy.max_hold_time = 50;

    let results = backtest(
        signals,
        &strategy,
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
    let mut strategy = default_strategy();
    strategy.stop_loss = 0.05;
    strategy.max_hold_time = 50;

    let results = backtest(
        signals,
        &strategy,
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
    let mut strategy = default_strategy();
    strategy.max_hold_time = 2;

    let results = backtest(
        signals,
        &strategy,
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
    let mut strategy = default_strategy();
    strategy.max_hold_time = 50;

    let results = backtest(
        signals,
        &strategy,
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
    let strategy = default_strategy();

    let results = backtest(
        signals,
        &strategy,
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
    let strategy = default_strategy();

    let results = backtest(signals, &strategy, &schema, &close_prices);
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
    let strategy = default_strategy();

    let results = backtest(signals, &strategy, &schema, &close_prices);

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
    let mut strategy = default_strategy();
    strategy.qty = 1.0;
    strategy.max_hold_time = 50;

    let results = backtest(
        signals,
        &strategy,
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
    let strategy = default_strategy();

    let results = backtest(
        signals,
        &strategy,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.entries, 1);
    assert!(results.final_state.lot.is_some());
}

#[test]
fn test_strong_entry_blocks_conflicting_signal() {
    let close_prices = vec![100.0, 100.0, 100.0];
    let entries = vec![true, false, false];
    let exits = vec![true, false, false];
    let signals = signals_from(entries, exits);
    let mut strategy = default_strategy();
    strategy.strong_entry = true;

    let results = backtest(
        signals,
        &strategy,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.entries, 0);
}

#[test]
fn test_strong_exit_blocks_conflicting_signal() {
    let close_prices = vec![100.0, 100.0, 100.0];
    let entries = vec![true, true, false];
    let exits = vec![false, true, false];
    let signals = signals_from(entries, exits);
    let mut strategy = default_strategy();
    strategy.strong_exit = true;

    let results = backtest(
        signals,
        &strategy,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.signal_exits, 0);
    assert!(results.final_state.lot.is_some());
}
