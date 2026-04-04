use std::collections::HashMap;

use alphchemy::experiment::strategy::{NetSignals, EntrySchema, ExitSchema};
use alphchemy::experiment::backtest::{BacktestSchema, backtest};
use alphchemy::network::network::{Anchor, NodePtr};

fn default_node_ptr() -> NodePtr {
    NodePtr { anchor: Anchor::FromEnd, idx: 0 }
}

fn default_entry_schema() -> EntrySchema {
    EntrySchema {
        id: "entry".to_string(),
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

fn default_global_max_positions() -> usize {
    10
}

fn make_exit_schema(id: &str, entry_ids: Vec<&str>, stop_loss: f64, take_profit: f64, max_hold_time: usize) -> ExitSchema {
    let mut exit_entry_ids = Vec::with_capacity(entry_ids.len());

    for entry_id in entry_ids {
        exit_entry_ids.push(entry_id.to_string());
    }

    ExitSchema {
        id: id.to_string(),
        node_ptr: default_node_ptr(),
        entry_ids: exit_entry_ids,
        stop_loss,
        take_profit,
        max_hold_time
    }
}

fn signal_map(pairs: &[(&str, bool)]) -> HashMap<String, bool> {
    let mut signals = HashMap::with_capacity(pairs.len());

    for pair in pairs {
        let schema_id = pair.0.to_string();
        let value = pair.1;
        signals.insert(schema_id, value);
    }

    signals
}

fn make_net_signal(entry_pairs: &[(&str, bool)], exit_pairs: &[(&str, bool)]) -> NetSignals {
    let entries = signal_map(entry_pairs);
    let exits = signal_map(exit_pairs);

    NetSignals {
        entries,
        exits
    }
}

fn signals_from(entries: Vec<bool>, exits: Vec<bool>) -> Vec<NetSignals> {
    assert_eq!(entries.len(), exits.len());
    entries.into_iter().zip(exits).map(|(entry, exit)| {
        make_net_signal(&[("entry", entry)], &[("exit", exit)])
    }).collect()
}

fn multi_signals_from(entry_ids: &[&str], exit_ids: &[&str], entries: Vec<Vec<bool>>, exits: Vec<Vec<bool>>) -> Vec<NetSignals> {
    assert_eq!(entries.len(), exits.len());
    let mut signals = Vec::with_capacity(entries.len());

    for i in 0..entries.len() {
        let entry_values = &entries[i];
        let exit_values = &exits[i];
        assert_eq!(entry_ids.len(), entry_values.len());
        assert_eq!(exit_ids.len(), exit_values.len());

        let mut entry_pairs = Vec::with_capacity(entry_ids.len());
        for j in 0..entry_ids.len() {
            let entry_id = entry_ids[j];
            let entry_value = entry_values[j];
            entry_pairs.push((entry_id, entry_value));
        }

        let mut exit_pairs = Vec::with_capacity(exit_ids.len());
        for j in 0..exit_ids.len() {
            let exit_id = exit_ids[j];
            let exit_value = exit_values[j];
            exit_pairs.push((exit_id, exit_value));
        }

        signals.push(make_net_signal(&entry_pairs, &exit_pairs));
    }

    signals
}

#[test]
fn test_take_profit_exit() {
    let close_prices = vec![100.0, 100.0, 110.0, 110.0, 110.0];
    let entries = vec![true, false, false, false, false];
    let exits = vec![false, false, false, false, false];
    let signals = signals_from(entries, exits);

    let exit_schema = make_exit_schema("exit", vec!["entry"], 0.05, 0.05, 50);

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
        default_global_max_positions(),
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

    let exit_schema = make_exit_schema("exit", vec!["entry"], 0.05, 0.5, 50);

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
        default_global_max_positions(),
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

    let exit_schema = make_exit_schema("exit", vec!["entry"], 0.5, 0.5, 2);

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
        default_global_max_positions(),
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

    let exit_schema = make_exit_schema("exit", vec!["entry"], 0.5, 0.5, 50);

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
        default_global_max_positions(),
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
        id: "entry".to_string(),
        node_ptr: default_node_ptr(),
        position_size: 0.1,
        max_positions: 2
    };

    let exit_schema = make_exit_schema("exit", vec!["entry"], 0.5, 0.5, 100);

    let results = backtest(
        signals,
        &[entry_schema],
        &[exit_schema],
        default_global_max_positions(),
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

    let exit_schema = make_exit_schema("exit", vec!["entry"], 0.5, 0.5, 100);

    let results = backtest(
        signals,
        &[default_entry_schema()],
        &[exit_schema],
        default_global_max_positions(),
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
        id: "entry".to_string(),
        node_ptr: default_node_ptr(),
        position_size: 1.0,
        max_positions: 10
    };

    let exit_schema = make_exit_schema("exit", vec!["entry"], 0.99, 0.99, 2);

    let results = backtest(
        signals,
        &[entry_schema],
        &[exit_schema],
        default_global_max_positions(),
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
        id: "entry".to_string(),
        node_ptr: default_node_ptr(),
        position_size: 1.0,
        max_positions: 1
    };

    let exit_schema = make_exit_schema("exit", vec!["entry"], 0.5, 0.5, 50);

    let schema = BacktestSchema {
        start_offset: 0,
        start_balance: 10000.0,
        delay: 0
    };

    let results = backtest(
        signals,
        &[entry_schema],
        &[exit_schema],
        default_global_max_positions(),
        &schema,
        &close_prices
    );

    assert!(results.final_state.balance > 10000.0);
}

#[test]
fn test_global_max_positions_respected() {
    let close_prices = vec![100.0, 100.0, 100.0];
    let signals = multi_signals_from(
        &["entry_0", "entry_1"],
        &["exit_0", "exit_1"],
        vec![
            vec![true, true],
            vec![true, true],
            vec![false, false]
        ],
        vec![
            vec![false, false],
            vec![false, false],
            vec![false, false]
        ]
    );

    let entry_schemas = vec![
        EntrySchema {
            id: "entry_0".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        },
        EntrySchema {
            id: "entry_1".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        }
    ];
    let exit_schemas = vec![
        make_exit_schema("exit_0", vec!["entry_0"], 0.5, 0.5, 100),
        make_exit_schema("exit_1", vec!["entry_1"], 0.5, 0.5, 100)
    ];

    let results = backtest(
        signals,
        &entry_schemas,
        &exit_schemas,
        2,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.entries, 2);
    assert_eq!(results.final_state.lots.len(), 2);
}

#[test]
fn test_global_max_positions_uses_entry_order() {
    let close_prices = vec![100.0, 100.0];
    let signals = multi_signals_from(
        &["entry_0", "entry_1"],
        &["exit_0", "exit_1"],
        vec![
            vec![true, true],
            vec![false, false]
        ],
        vec![
            vec![false, false],
            vec![false, false]
        ]
    );

    let entry_schemas = vec![
        EntrySchema {
            id: "entry_0".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        },
        EntrySchema {
            id: "entry_1".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        }
    ];
    let exit_schemas = vec![
        make_exit_schema("exit_0", vec!["entry_0"], 0.5, 0.5, 100),
        make_exit_schema("exit_1", vec!["entry_1"], 0.5, 0.5, 100)
    ];

    let results = backtest(
        signals,
        &entry_schemas,
        &exit_schemas,
        1,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.entries, 1);
    assert_eq!(results.final_state.lots[0].schema_id, "entry_0");
}

#[test]
fn test_global_max_positions_frees_slot_after_exit() {
    let close_prices = vec![100.0, 100.0, 100.0];
    let signals = multi_signals_from(
        &["entry_0", "entry_1"],
        &["exit_0", "exit_1"],
        vec![
            vec![true, false],
            vec![false, true],
            vec![false, false]
        ],
        vec![
            vec![false, false],
            vec![true, false],
            vec![false, false]
        ]
    );

    let entry_schemas = vec![
        EntrySchema {
            id: "entry_0".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        },
        EntrySchema {
            id: "entry_1".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        }
    ];
    let exit_schemas = vec![
        make_exit_schema("exit_0", vec!["entry_0"], 0.5, 0.5, 100),
        make_exit_schema("exit_1", vec!["entry_1"], 0.5, 0.5, 100)
    ];

    let results = backtest(
        signals,
        &entry_schemas,
        &exit_schemas,
        1,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.entries, 2);
    assert_eq!(results.final_state.signal_exits, 1);
    assert_eq!(results.final_state.lots.len(), 1);
    assert_eq!(results.final_state.lots[0].schema_id, "entry_1");
}

#[test]
fn test_entry_signal_uses_schema_id() {
    let close_prices = vec![100.0, 100.0];
    let signals = vec![
        make_net_signal(
            &[("entry_1", true), ("entry_0", false)],
            &[("exit_1", false), ("exit_0", false)]
        ),
        make_net_signal(
            &[("entry_1", false), ("entry_0", false)],
            &[("exit_1", false), ("exit_0", false)]
        )
    ];

    let entry_schemas = vec![
        EntrySchema {
            id: "entry_0".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        },
        EntrySchema {
            id: "entry_1".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        }
    ];
    let exit_schemas = vec![
        make_exit_schema("exit_0", vec!["entry_0"], 0.5, 0.5, 100),
        make_exit_schema("exit_1", vec!["entry_1"], 0.5, 0.5, 100)
    ];

    let results = backtest(
        signals,
        &entry_schemas,
        &exit_schemas,
        1,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.entries, 1);
    assert_eq!(results.final_state.lots[0].schema_id, "entry_1");
}

#[test]
fn test_exit_signal_uses_schema_id() {
    let close_prices = vec![100.0, 100.0, 100.0];
    let signals = vec![
        make_net_signal(
            &[("entry_1", true), ("entry_0", true)],
            &[("exit_1", false), ("exit_0", false)]
        ),
        make_net_signal(
            &[("entry_1", false), ("entry_0", false)],
            &[("exit_1", true), ("exit_0", false)]
        ),
        make_net_signal(
            &[("entry_1", false), ("entry_0", false)],
            &[("exit_1", false), ("exit_0", false)]
        )
    ];

    let entry_schemas = vec![
        EntrySchema {
            id: "entry_0".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        },
        EntrySchema {
            id: "entry_1".to_string(),
            node_ptr: default_node_ptr(),
            position_size: 0.1,
            max_positions: 5
        }
    ];
    let exit_schemas = vec![
        make_exit_schema("exit_0", vec!["entry_0"], 0.5, 0.5, 100),
        make_exit_schema("exit_1", vec!["entry_1"], 0.5, 0.5, 100)
    ];

    let results = backtest(
        signals,
        &entry_schemas,
        &exit_schemas,
        2,
        &default_backtest_schema(),
        &close_prices
    );

    assert_eq!(results.final_state.signal_exits, 1);
    assert_eq!(results.final_state.lots.len(), 1);
    assert_eq!(results.final_state.lots[0].schema_id, "entry_0");
}
