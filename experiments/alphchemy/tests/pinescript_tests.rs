use alphchemy::actions::logic_actions::LogicActions;
use alphchemy::experiment::backtest::BacktestSchema;
use alphchemy::experiment::experiment::{Experiment, ExperimentVariant};
use alphchemy::experiment::strategy::Strategy;
use alphchemy::features::features::{Constant, Feature, OHLC, RSI};
use alphchemy::features::indicators::{
    BBOutput,
    DCOutput,
    NormalizedBB,
    NormalizedDC,
    NormalizedSMA,
    Stochastic,
    StochasticOutput
};
use alphchemy::network::decision_net::{BranchNode, DecisionNet, DecisionNode, RefNode};
use alphchemy::network::logic_net::{Gate, GateNode, InputNode, LogicNet, LogicNode, LogicPenalties};
use alphchemy::network::network::{Anchor, NodePtr};
use alphchemy::optimizer::genetic::GeneticOpt;
use alphchemy::optimizer::optimizer::StopConds;
use alphchemy::pinescript::features_to_ps::emit_feats;
use alphchemy::pinescript::net_to_ps::NetToPs;
use alphchemy::pinescript::to_pinescript::{CUSTOM_HELPERS, FoldPeriods, experiment_to_pinescript};
use std::collections::HashMap;

#[test]
fn test_decision_net_pinescript_matches_rust_trail_limit() {
    let net = DecisionNet {
        nodes: vec![
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_id: Some("feat_a".to_string()),
                true_idx: Some(0),
                false_idx: None,
                value: false
            })
        ],
        max_trail_len: 3,
        default_value: false,
        idx_trail: Vec::new()
    };

    let emit = net.emit(0).unwrap();
    let per_bar = emit.per_bar.join("\n");

    assert!(per_bar.contains("while current_idx >= 0"));
    assert!(per_bar.contains("if array.size(trail) >= 3"));
    assert!(!per_bar.contains("if array.size(trail) > 3"));
    assert!(!per_bar.contains("for step ="));
    assert!(!per_bar.contains("keep_iterating"));
}

#[test]
fn test_generated_strategy_processes_market_orders_on_close() {
    let net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.0),
                feat_id: Some("signal".to_string()),
                value: false
            })
        ],
        default_value: false
    };
    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: HashMap::new(),
        feat_order: vec!["signal".to_string()],
        n_thresholds: 1,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And]
    };
    let penalties = LogicPenalties {
        node: 0.0,
        input: 0.0,
        gate: 0.0,
        recurrence: 0.0,
        feedforward: 0.0,
        used_feat: 0.0,
        unused_feat: 0.0
    };
    let stop_conds = StopConds {
        max_iters: 1,
        train_patience: 1,
        val_patience: 1
    };
    let opt = GeneticOpt {
        pop_size: 1,
        seq_len: 1,
        n_elites: 0,
        mut_rate: 0.0,
        cross_rate: 0.0,
        tourn_size: 1,
        objectives: Vec::new(),
        random_seed: Some(1)
    };
    let schema = BacktestSchema {
        start_offset: 0,
        start_balance: 10000.0,
        delay: 0,
        metrics: Vec::new()
    };
    let node_ptr = NodePtr { anchor: Anchor::FromStart, idx: 0 };
    let strategy = Strategy {
        base_net: net,
        feats: vec![
            Feature::Constant(Constant {
                id: "signal".to_string(),
                constant: 1.0
            })
        ],
        actions,
        penalties,
        stop_conds,
        opt,
        entry_ptr: node_ptr.clone(),
        exit_ptr: node_ptr,
        stop_loss: 0.04,
        take_profit: 0.08,
        max_hold_time: 1,
        qty: 1.0
    };
    let experiment = Experiment {
        val_size: 0.2,
        test_size: 0.2,
        cv_folds: 1,
        fold_size: 1.0,
        symbol: "BTC_USDT".to_string(),
        start_timestamp: "2024-01-01T00:00:00".to_string(),
        end_timestamp: "2024-01-02T00:00:00".to_string(),
        backtest_schema: schema,
        strategy
    };
    let periods = FoldPeriods {
        train_start_timestamp: "2024-01-01T00:00:00".to_string(),
        train_end_timestamp: "2024-01-01T06:00:00".to_string(),
        val_start_timestamp: "2024-01-01T07:00:00".to_string(),
        val_end_timestamp: "2024-01-01T12:00:00".to_string(),
        test_start_timestamp: "2024-01-01T13:00:00".to_string(),
        test_end_timestamp: "2024-01-02T00:00:00".to_string()
    };
    let variant = ExperimentVariant::Logic(experiment);
    let pinescript = experiment_to_pinescript(&variant, "Timing Test", &[], &periods).unwrap();

    assert!(pinescript.contains("// Training period: Jan 1 2024 00:00 to Jan 1 2024 06:00"));
    assert!(pinescript.contains("// Validation period: Jan 1 2024 07:00 to Jan 1 2024 12:00"));
    assert!(pinescript.contains("// Out-of-sample test period: Jan 1 2024 13:00 to Jan 2 2024 00:00"));
    assert!(pinescript.contains("strategy(\"Timing Test\", overlay=true, initial_capital=10000, process_orders_on_close=true)"));
    assert!(pinescript.contains("take_profit_hit = strategy.position_size > 0 and close > strategy.position_avg_price * 1.08"));
    assert!(pinescript.contains("stop_loss_hit = strategy.position_size > 0 and close < strategy.position_avg_price * 0.96"));
    assert!(pinescript.contains("risk_exit = take_profit_hit or stop_loss_hit or max_hold_hit"));
    assert!(pinescript.contains("if active and risk_exit\n    strategy.close(\"entry\", comment=\"risk_exit\")"));
    assert!(pinescript.contains("else if active and strategy.position_size > 0 and exit_signal\n    strategy.close(\"entry\", comment=\"signal_exit\")"));
    assert!(!pinescript.contains("strategy.exit("));
}

#[test]
fn test_logic_net_pinescript_matches_feedforward_and_recurrence() {
    let net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_id: Some("feat_a".to_string()),
                value: false
            }),
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_id: Some("feat_b".to_string()),
                value: false
            }),
            LogicNode::Gate(GateNode {
                gate: Some(Gate::Or),
                in1_idx: Some(0),
                in2_idx: Some(2),
                value: false
            })
        ],
        default_value: false
    };

    let emit = net.emit(2).unwrap();
    let per_bar = emit.per_bar.join("\n");

    assert!(per_bar.contains("n0 := feat_feat_a[2] > 0.5"));
    assert!(per_bar.contains("prev_n2 = n2"));
    assert!(per_bar.contains("n2 := n0 or prev_n2"));
}

#[test]
fn test_decision_net_pinescript_matches_ref_and_trail_pointers() {
    let net = DecisionNet {
        nodes: vec![
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_id: Some("feat_a".to_string()),
                true_idx: Some(1),
                false_idx: Some(2),
                value: false
            }),
            DecisionNode::Ref(RefNode {
                ref_idx: Some(0),
                true_idx: None,
                false_idx: None,
                value: false
            }),
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_id: Some("feat_b".to_string()),
                true_idx: None,
                false_idx: None,
                value: false
            })
        ],
        max_trail_len: 4,
        default_value: false,
        idx_trail: Vec::new()
    };

    let emit = net.emit(0).unwrap();
    let per_bar = emit.per_bar.join("\n");
    let start_ptr = NodePtr { anchor: Anchor::FromStart, idx: 1 };
    let end_ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };

    assert!(per_bar.contains("new_val := array.get(node_vals, 0)"));
    assert!(per_bar.contains("next_idx := new_val ? 1 : 2"));
    assert_eq!(net.node_value_expr(&start_ptr), "(array.size(trail) > 1 ? array.get(node_vals, array.get(trail, 1)) : default_value)");
    assert_eq!(net.node_value_expr(&end_ptr), "(array.size(trail) > 0 ? array.get(node_vals, array.get(trail, array.size(trail) - 0 - 1)) : default_value)");
}

#[test]
fn test_rsi_pinescript_first_bar_change_is_zero() {
    let feats: Vec<Feature> = vec![
        Feature::RSI(RSI {
            id: "rsi".to_string(),
            ohlc: OHLC::Close,
            window: 14,
            smooth: 2
        })
    ];

    let lines = emit_feats(&feats).unwrap();
    let pinescript = lines.join("\n");

    assert!(pinescript.contains("bar_index == 0 ? 0.0 : close - close[1]"));
}

#[test]
fn test_normalized_sma_pinescript_uses_custom_helpers() {
    let feats: Vec<Feature> = vec![
        Feature::NormalizedSMA(NormalizedSMA {
            id: "sma".to_string(),
            ohlc: OHLC::Close,
            window: 20
        })
    ];

    let pinescript = emit_feats(&feats).unwrap().join("\n");

    assert!(pinescript.contains("custom_sma(close, 20)"));
    assert!(pinescript.contains("nz("));
    assert!(!pinescript.contains("ta.sma("));
}

#[test]
fn test_custom_sma_pinescript_matches_rust_warmup() {
    assert!(CUSTOM_HELPERS.contains("custom_sma(source, window) =>\n    var float sum = 0.0\n    sum += source\n    if bar_index >= window\n        sum -= source[window]\n    if bar_index + 1 < window\n        0.0\n    else\n        sum / window"));
}

#[test]
fn test_custom_ema_pinescript_matches_rust_warmup() {
    assert!(CUSTOM_HELPERS.contains("custom_ema(source, window, smooth) =>"));
    assert!(CUSTOM_HELPERS.contains("if bar_index < window\n        seed += source"));
    assert!(CUSTOM_HELPERS.contains("prev"));
}

#[test]
fn test_normalized_bb_pinescript_uses_custom_helpers() {
    let feats: Vec<Feature> = vec![
        Feature::NormalizedBB(NormalizedBB {
            id: "bb".to_string(),
            ohlc: OHLC::Close,
            window: 20,
            std_multiplier: 2.0,
            output: BBOutput::Upper
        })
    ];

    let pinescript = emit_feats(&feats).unwrap().join("\n");

    assert!(pinescript.contains("custom_sma(close, 20)"));
    assert!(pinescript.contains("custom_stdev(close, 20)"));
    assert!(pinescript.contains("nz("));
    assert!(!pinescript.contains("ta.sma("));
    assert!(!pinescript.contains("ta.stdev("));
}

#[test]
fn test_custom_stdev_pinescript_matches_rust_warmup() {
    assert!(CUSTOM_HELPERS.contains("custom_stdev(source, window) =>\n    mean_val = custom_sma(source, window)\n    if bar_index + 1 < window\n        0.0"));
}

#[test]
fn test_stochastic_pinescript_uses_custom_helpers() {
    let feats: Vec<Feature> = vec![
        Feature::Stochastic(Stochastic {
            id: "stoch".to_string(),
            window: 14,
            smooth_window: 3,
            output: StochasticOutput::PercentD
        })
    ];

    let pinescript = emit_feats(&feats).unwrap().join("\n");

    assert!(pinescript.contains("custom_highest(high, 14)"));
    assert!(pinescript.contains("custom_lowest(low, 14)"));
    assert!(pinescript.contains("custom_sma("));
    assert!(pinescript.contains("nz((close - "));
    assert!(!pinescript.contains("ta.highest("));
    assert!(!pinescript.contains("ta.lowest("));
    assert!(!pinescript.contains("ta.sma("));
}

#[test]
fn test_normalized_dc_pinescript_uses_custom_helpers() {
    let feats: Vec<Feature> = vec![
        Feature::NormalizedDC(NormalizedDC {
            id: "dc".to_string(),
            window: 20,
            output: DCOutput::Width
        })
    ];

    let pinescript = emit_feats(&feats).unwrap().join("\n");

    assert!(pinescript.contains("custom_highest(high, 20)"));
    assert!(pinescript.contains("custom_lowest(low, 20)"));
    assert!(pinescript.contains("nz("));
    assert!(!pinescript.contains("ta.highest("));
    assert!(!pinescript.contains("ta.lowest("));
}

#[test]
fn test_custom_extrema_pinescript_match_rust_warmup() {
    assert!(CUSTOM_HELPERS.contains("custom_highest(source, window) =>\n    if bar_index + 1 < window\n        0.0"));
    assert!(CUSTOM_HELPERS.contains("custom_lowest(source, window) =>\n    if bar_index + 1 < window\n        0.0"));
}
