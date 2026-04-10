use std::collections::HashMap;

use alphchemy::actions::actions::{Action, ActionsState, ThresholdRange, construct_net};
use alphchemy::actions::logic_actions::LogicActions;
use alphchemy::network::logic_net::{LogicNet, LogicNode, InputNode, GateNode, Gate};
use serde_json::json;

fn threshold_map(entries: &[(&str, f64, f64)]) -> HashMap<String, ThresholdRange> {
    let mut thresholds = HashMap::new();

    for (feat_id, min, max) in entries {
        let range = ThresholdRange {
            min: *min,
            max: *max
        };
        thresholds.insert((*feat_id).to_string(), range);
    }

    thresholds
}

#[test]
fn test_threshold_range_value_at_min() {
    let range = ThresholdRange { min: 0.0, max: 10.0 };
    let value = range.value_at(0, 5);
    assert!((value - 0.0).abs() < 1e-10);
}

#[test]
fn test_threshold_range_value_at_max() {
    let range = ThresholdRange { min: 0.0, max: 10.0 };
    let value = range.value_at(4, 5);
    assert!((value - 10.0).abs() < 1e-10);
}

#[test]
fn test_threshold_range_value_at_mid() {
    let range = ThresholdRange { min: 0.0, max: 10.0 };
    let value = range.value_at(2, 5);
    assert!((value - 5.0).abs() < 1e-10);
}

#[test]
fn test_threshold_range_single_threshold() {
    let range = ThresholdRange { min: 3.0, max: 7.0 };
    let value = range.value_at(0, 1);
    assert!((value - 3.0).abs() < 1e-10);
}

#[test]
fn test_actions_state_next_feat_wraps() {
    let mut state = ActionsState {
        feat_idx: 0,
        node_idx: 0,
        selected_idx: 0,
        threshold_idx: 0,
        extra_idx: 0
    };

    state.next_feat(3);
    assert_eq!(state.feat_idx, 1);
    state.next_feat(3);
    assert_eq!(state.feat_idx, 2);
    state.next_feat(3);
    assert_eq!(state.feat_idx, 0);
}

#[test]
fn test_actions_state_next_node_wraps() {
    let mut state = ActionsState {
        feat_idx: 0,
        node_idx: 0,
        selected_idx: 0,
        threshold_idx: 0,
        extra_idx: 0
    };

    state.next_node(2);
    assert_eq!(state.node_idx, 1);
    state.next_node(2);
    assert_eq!(state.node_idx, 0);
}

#[test]
fn test_actions_state_select_node() {
    let mut state = ActionsState {
        feat_idx: 0,
        node_idx: 0,
        selected_idx: 0,
        threshold_idx: 0,
        extra_idx: 0
    };

    state.next_node(5);
    state.next_node(5);
    state.select_node();
    assert_eq!(state.selected_idx, 2);
}

#[test]
fn test_action_serializes_as_string_label() {
    let built_in = serde_json::to_value(Action::NextFeat).unwrap();
    let meta_action = serde_json::to_value(Action::MetaAction("rewire".to_string())).unwrap();

    assert_eq!(built_in, json!("next_feat"));
    assert_eq!(meta_action, json!("rewire"));
}

#[test]
fn test_action_does_not_deserialize_meta_action_label() {
    let result = serde_json::from_value::<Action>(json!("rewire"));
    assert!(result.is_err());
}

#[test]
fn test_construct_net_empty_seq() {
    let base_net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: Some(0.5),
                feat_id: Some("feat_a".to_string()),
                value: false
            })
        ],
        default_value: false
    };

    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: threshold_map(&[
            ("feat_a", 0.0, 1.0)
        ]),
        feat_order: vec!["feat_a".to_string()],
        n_thresholds: 5,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And, Gate::Or]
    };

    let net = construct_net(&base_net, &[], &actions);
    assert_eq!(net.nodes.len(), 1);
}

#[test]
fn test_construct_net_new_input_grows_net() {
    let base_net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: None,
                feat_id: None,
                value: false
            })
        ],
        default_value: false
    };

    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: threshold_map(&[
            ("feat_a", 0.0, 1.0)
        ]),
        feat_order: vec!["feat_a".to_string()],
        n_thresholds: 5,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And]
    };

    let seq = vec![Action::NewInput, Action::NewInput, Action::NewGate];
    let net = construct_net(&base_net, &seq, &actions);
    assert_eq!(net.nodes.len(), 4);
}

#[test]
fn test_construct_net_set_feat() {
    let base_net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode {
                threshold: None,
                feat_id: None,
                value: false
            })
        ],
        default_value: false
    };

    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: threshold_map(&[
            ("feat_a", 0.0, 1.0),
            ("feat_b", 0.0, 1.0)
        ]),
        feat_order: vec!["feat_a".to_string(), "feat_b".to_string()],
        n_thresholds: 5,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And]
    };

    let seq = vec![Action::NextFeat, Action::SetFeat];
    let net = construct_net(&base_net, &seq, &actions);

    if let LogicNode::Input(input) = &net.nodes[0] {
        assert_eq!(input.feat_id.as_deref(), Some("feat_b"));
    } else {
        panic!("expected input node");
    }
}

#[test]
fn test_construct_net_set_gate() {
    let base_net = LogicNet {
        nodes: vec![
            LogicNode::Gate(GateNode {
                gate: None,
                in1_idx: None,
                in2_idx: None,
                value: false
            })
        ],
        default_value: false
    };

    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: threshold_map(&[
            ("feat_a", 0.0, 1.0)
        ]),
        feat_order: vec!["feat_a".to_string()],
        n_thresholds: 5,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And, Gate::Or]
    };

    let seq = vec![Action::NextGate, Action::SetGate];
    let net = construct_net(&base_net, &seq, &actions);

    if let LogicNode::Gate(gate) = &net.nodes[0] {
        assert!(gate.gate.is_some());
    } else {
        panic!("expected gate node");
    }
}
