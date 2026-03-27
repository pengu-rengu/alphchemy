use alphchemy::network::network::Penalties;
use alphchemy::network::logic_net::{
    LogicNet, LogicNode, InputNode, GateNode, Gate, LogicPenalties
};
use alphchemy::network::decision_net::{
    DecisionNet, DecisionNode, BranchNode, RefNode, DecisionPenalties
};

fn zero_logic_penalties() -> LogicPenalties {
    LogicPenalties {
        node: 0.0,
        input: 0.0,
        gate: 0.0,
        recurrence: 0.0,
        feedforward: 0.0,
        used_feat: 0.0,
        unused_feat: 0.0
    }
}

#[test]
fn test_logic_penalties_empty_net() {
    let net = LogicNet { nodes: vec![], default_value: false };
    let penalties = LogicPenalties {
        node: 1.0,
        input: 1.0,
        gate: 1.0,
        recurrence: 1.0,
        feedforward: 1.0,
        used_feat: 1.0,
        unused_feat: 1.0
    };
    let score = penalties.penalty(&net, 0);
    assert!((score - 0.0).abs() < 1e-10);
}

#[test]
fn test_logic_penalties_node_counting() {
    let net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: None,
                feat_idx: None,
                value: false
            }),
            LogicNode::Input(InputNode {
                threshold: None,
                feat_idx: None,
                value: false
            }),
            LogicNode::Gate(GateNode {
                gate: None,
                in1_idx: None,
                in2_idx: None,
                value: false
            })
        ],
        default_value: false
    };

    let mut penalties = zero_logic_penalties();
    penalties.node = 1.0;
    penalties.input = 2.0;
    penalties.gate = 3.0;

    let score = penalties.nodes_penalty(&net);
    let expected = 3.0 + 2.0 + 2.0 + 3.0;
    assert!((score - expected).abs() < 1e-10);
}

#[test]
fn test_logic_penalties_feedforward_vs_recurrence() {
    let net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: None,
                feat_idx: None,
                value: false
            }),
            LogicNode::Gate(GateNode {
                gate: Some(Gate::And),
                in1_idx: Some(0),
                in2_idx: Some(1),
                value: false
            })
        ],
        default_value: false
    };

    let mut penalties = zero_logic_penalties();
    penalties.feedforward = 1.0;
    penalties.recurrence = 10.0;

    let score = penalties.directions_penalty(&net);
    let expected = 1.0 + 10.0;
    assert!((score - expected).abs() < 1e-10);
}

#[test]
fn test_logic_penalties_feats_used_vs_unused() {
    let net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                value: false
            })
        ],
        default_value: false
    };

    let mut penalties = zero_logic_penalties();
    penalties.used_feat = 1.0;
    penalties.unused_feat = 5.0;

    let score = penalties.feats_penalty(&net, 3);
    let expected = 1.0 + 5.0 + 5.0;
    assert!((score - expected).abs() < 1e-10);
}

#[test]
fn test_decision_penalties_node_counting() {
    let net = DecisionNet {
        nodes: vec![
            DecisionNode::Branch(BranchNode {
                threshold: None,
                feat_idx: None,
                true_idx: None,
                false_idx: None,
                value: false
            }),
            DecisionNode::Ref(RefNode {
                ref_idx: None,
                true_idx: None,
                false_idx: None,
                value: false
            })
        ],
        max_trail_len: 10,
        default_value: false,
        idx_trail: Vec::new()
    };

    let penalties = DecisionPenalties {
        node: 1.0,
        branch: 2.0,
        ref_: 3.0,
        leaf: 0.0,
        non_leaf: 0.0,
        used_feat: 0.0,
        unused_feat: 0.0
    };

    let score = penalties.nodes_penalty(&net);
    let expected = 1.0 + 2.0 + 1.0 + 3.0;
    assert!((score - expected).abs() < 1e-10);
}

#[test]
fn test_decision_penalties_leaf_vs_non_leaf() {
    let net = DecisionNet {
        nodes: vec![
            DecisionNode::Branch(BranchNode {
                threshold: None,
                feat_idx: None,
                true_idx: Some(1),
                false_idx: None,
                value: false
            }),
            DecisionNode::Branch(BranchNode {
                threshold: None,
                feat_idx: None,
                true_idx: None,
                false_idx: None,
                value: false
            })
        ],
        max_trail_len: 10,
        default_value: false,
        idx_trail: Vec::new()
    };

    let penalties = DecisionPenalties {
        node: 0.0,
        branch: 0.0,
        ref_: 0.0,
        leaf: 1.0,
        non_leaf: 5.0,
        used_feat: 0.0,
        unused_feat: 0.0
    };

    let score = penalties.leaves_penalty(&net);
    let expected = 5.0 + 1.0 + 1.0 + 1.0;
    assert!((score - expected).abs() < 1e-10);
}
