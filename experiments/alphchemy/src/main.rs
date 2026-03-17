mod network;
mod features;
mod actions;
mod optimizer;

use network::network::*;
use network::logic_net::*;
use actions::actions::*;
use actions::logic_actions::*;
use optimizer::optimizer::*;
use std::collections::HashMap;



struct Strategy<T: Network, P: Penalties<T>, A: Actions<T>> {
    net: T,
    penalties: P,
    actions: A
}

fn main() {
    let net = LogicNet {
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
        default_value: false,
    };
    let penalties = LogicPenalties {
        node: 0.0,
        input: 0.0,
        gate: 0.0,
        recurrence: 0.0,
        feedforward: 0.0,
        used_feat: 0.0,
        unused_feat: 1.0
    };
    let actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: vec![],
        n_thresholds: 1,
        allow_recurrence: true,
        allowed_gates: vec![]
    };

    let mut strategy = Strategy {
        net,
        penalties,
        actions
    };
    
    strategy.net.eval(&vec![0.0, 1.0]);
    println!("{:?}", strategy.net.nodes[2].value());

    println!("{:?}", strategy.penalties.penalty(&strategy.net, 10));

    println!("{:?}", strategy.actions.actions_list())   
}
