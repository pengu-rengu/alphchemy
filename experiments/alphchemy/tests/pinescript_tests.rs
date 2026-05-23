use alphchemy::features::features::{Feature, OHLC, RSI};
use alphchemy::network::decision_net::{BranchNode, DecisionNet, DecisionNode};
use alphchemy::pinescript::features_to_ps::emit_feats;
use alphchemy::pinescript::net_to_ps::NetToPs;

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

    assert!(per_bar.contains("if array.size(trail) >= 3"));
    assert!(!per_bar.contains("if array.size(trail) > 3"));
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
