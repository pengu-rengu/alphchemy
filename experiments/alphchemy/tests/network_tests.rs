use alphchemy::network::network::{Network, Anchor, NodePtr};
use alphchemy::network::logic_net::{LogicNet, LogicNode, InputNode, GateNode, Gate};
use alphchemy::network::decision_net::{DecisionNet, DecisionNode, BranchNode, RefNode};

fn logic_net_and_gate() -> LogicNet {
    LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                value: false
            }),
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(1),
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
    }
}

#[test]
fn test_logic_net_and_gate_both_true() {
    let mut net = logic_net_and_gate();
    let row = [1.0, 1.0];
    net.eval(&row);

    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(net.node_value(&ptr));
}

#[test]
fn test_logic_net_and_gate_one_false() {
    let mut net = logic_net_and_gate();
    let row = [1.0, 0.0];
    net.eval(&row);

    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(!net.node_value(&ptr));
}

#[test]
fn test_logic_net_or_gate() {
    let mut net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                value: false
            }),
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(1),
                value: false
            }),
            LogicNode::Gate(GateNode {
                gate: Some(Gate::Or),
                in1_idx: Some(0),
                in2_idx: Some(1),
                value: false
            })
        ],
        default_value: false
    };

    let row = [1.0, 0.0];
    net.eval(&row);

    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(net.node_value(&ptr));
}

#[test]
fn test_logic_net_xor_gate() {
    let mut net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                value: false
            }),
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_idx: Some(1),
                value: false
            }),
            LogicNode::Gate(GateNode {
                gate: Some(Gate::Xor),
                in1_idx: Some(0),
                in2_idx: Some(1),
                value: false
            })
        ],
        default_value: false
    };

    let row_same = [1.0, 1.0];
    net.eval(&row_same);
    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(!net.node_value(&ptr));

    net.reset_state();
    let row_diff = [1.0, 0.0];
    net.eval(&row_diff);
    assert!(net.node_value(&ptr));
}

#[test]
fn test_logic_net_default_value_fallback() {
    let mut net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: None,
                feat_idx: None,
                value: false
            })
        ],
        default_value: true
    };

    net.eval(&[0.5]);
    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(net.node_value(&ptr));
}

#[test]
fn test_logic_net_reset_state() {
    let mut net = logic_net_and_gate();
    net.eval(&[1.0, 1.0]);

    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(net.node_value(&ptr));

    net.reset_state();
    assert!(!net.node_value(&ptr));
}

#[test]
fn test_decision_net_branch_traversal() {
    let mut net = DecisionNet {
        nodes: vec![
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                true_idx: Some(1),
                false_idx: None,
                value: false
            }),
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                true_idx: None,
                false_idx: None,
                value: false
            })
        ],
        max_trail_len: 10,
        default_value: false,
        idx_trail: Vec::new()
    };

    net.eval(&[1.0]);
    assert_eq!(net.idx_trail.len(), 2);
    assert_eq!(net.idx_trail[0], 0);
    assert_eq!(net.idx_trail[1], 1);
}

#[test]
fn test_decision_net_ref_node() {
    let mut net = DecisionNet {
        nodes: vec![
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                true_idx: Some(1),
                false_idx: None,
                value: false
            }),
            DecisionNode::Ref(RefNode {
                ref_idx: Some(0),
                true_idx: None,
                false_idx: None,
                value: false
            })
        ],
        max_trail_len: 10,
        default_value: false,
        idx_trail: Vec::new()
    };

    net.eval(&[1.0]);
    assert_eq!(net.idx_trail.len(), 2);
}

#[test]
fn test_decision_net_max_trail_len() {
    let mut net = DecisionNet {
        nodes: vec![
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                true_idx: Some(1),
                false_idx: Some(1),
                value: false
            }),
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_idx: Some(0),
                true_idx: Some(0),
                false_idx: Some(0),
                value: false
            })
        ],
        max_trail_len: 3,
        default_value: false,
        idx_trail: Vec::new()
    };

    net.eval(&[1.0]);
    assert!(net.idx_trail.len() <= 3);
}

#[test]
fn test_decision_net_empty() {
    let mut net = DecisionNet {
        nodes: vec![],
        max_trail_len: 10,
        default_value: false,
        idx_trail: Vec::new()
    };

    net.eval(&[1.0]);
    assert!(net.idx_trail.is_empty());
}
