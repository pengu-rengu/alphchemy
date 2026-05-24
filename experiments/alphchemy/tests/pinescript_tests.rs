use alphchemy::features::features::{Feature, OHLC, RSI};
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
use alphchemy::network::logic_net::{Gate, GateNode, InputNode, LogicNet, LogicNode};
use alphchemy::network::network::{Anchor, NodePtr};
use alphchemy::pinescript::features_to_ps::emit_feats;
use alphchemy::pinescript::net_to_ps::NetToPs;
use alphchemy::pinescript::to_pinescript::CUSTOM_HELPERS;

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
    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(RSI {
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
    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(NormalizedSMA {
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
    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(NormalizedBB {
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
    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(Stochastic {
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
    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(NormalizedDC {
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
