use std::collections::HashMap;
use ndarray::Array1;
use alphchemy::features::features::FeatTable;
use alphchemy::network::network::{Network, Anchor, NodePtr};
use alphchemy::network::logic_net::{LogicNet, LogicNode, InputNode, GateNode, Gate};
use alphchemy::network::decision_net::{DecisionNet, DecisionNode, BranchNode, RefNode};

fn make_feat_table(entries: &[(&str, &[f64])]) -> FeatTable {
    let mut feat_table = HashMap::new();

    for (feat_id, values) in entries {
        let array = Array1::from_vec(values.to_vec());
        feat_table.insert((*feat_id).to_string(), array);
    }

    feat_table
}

fn logic_net_and_gate() -> LogicNet {
    LogicNet {
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
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0]),
        ("feat_b", &[1.0])
    ]);
    net.eval(&feat_table, 0);

    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(net.node_value(&ptr));
}

#[test]
fn test_logic_net_and_gate_one_false() {
    let mut net = logic_net_and_gate();
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0]),
        ("feat_b", &[0.0])
    ]);
    net.eval(&feat_table, 0);

    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(!net.node_value(&ptr));
}

#[test]
fn test_logic_net_or_gate() {
    let mut net = LogicNet {
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
                in2_idx: Some(1),
                value: false
            })
        ],
        default_value: false
    };
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0]),
        ("feat_b", &[0.0])
    ]);

    net.eval(&feat_table, 0);

    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(net.node_value(&ptr));
}

#[test]
fn test_logic_net_xor_gate() {
    let mut net = LogicNet {
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
                gate: Some(Gate::Xor),
                in1_idx: Some(0),
                in2_idx: Some(1),
                value: false
            })
        ],
        default_value: false
    };
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0, 1.0]),
        ("feat_b", &[1.0, 0.0])
    ]);

    net.eval(&feat_table, 0);
    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(!net.node_value(&ptr));

    net.reset_state();
    net.eval(&feat_table, 1);
    assert!(net.node_value(&ptr));
}

#[test]
fn test_logic_net_default_value_fallback() {
    let mut net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: None,
                feat_id: None,
                value: false
            })
        ],
        default_value: true
    };
    let feat_table = make_feat_table(&[
        ("feat_a", &[0.5])
    ]);

    net.eval(&feat_table, 0);
    let ptr = NodePtr { anchor: Anchor::FromEnd, idx: 0 };
    assert!(net.node_value(&ptr));
}

#[test]
fn test_logic_net_reset_state() {
    let mut net = logic_net_and_gate();
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0]),
        ("feat_b", &[1.0])
    ]);
    net.eval(&feat_table, 0);

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
                feat_id: Some("feat_a".to_string()),
                true_idx: Some(1),
                false_idx: None,
                value: false
            }),
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_id: Some("feat_a".to_string()),
                true_idx: None,
                false_idx: None,
                value: false
            })
        ],
        max_trail_len: 10,
        default_value: false,
        idx_trail: Vec::new()
    };
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0])
    ]);

    net.eval(&feat_table, 0);
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
                feat_id: Some("feat_a".to_string()),
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
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0])
    ]);

    net.eval(&feat_table, 0);
    assert_eq!(net.idx_trail.len(), 2);
}

#[test]
fn test_decision_net_max_trail_len() {
    let mut net = DecisionNet {
        nodes: vec![
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_id: Some("feat_a".to_string()),
                true_idx: Some(1),
                false_idx: Some(1),
                value: false
            }),
            DecisionNode::Branch(BranchNode {
                threshold: Some(0.5),
                feat_id: Some("feat_a".to_string()),
                true_idx: Some(0),
                false_idx: Some(0),
                value: false
            })
        ],
        max_trail_len: 3,
        default_value: false,
        idx_trail: Vec::new()
    };
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0])
    ]);

    net.eval(&feat_table, 0);
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
    let feat_table = make_feat_table(&[
        ("feat_a", &[1.0])
    ]);

    net.eval(&feat_table, 0);
    assert!(net.idx_trail.is_empty());
}
