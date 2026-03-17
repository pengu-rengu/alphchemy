use ndarray::Array2;

use crate::network::network::{Network, NodePtr, Penalties};
use crate::features::features::Feature;
use crate::actions::actions::Actions;
use crate::optimizer::optimizer::StopConds;
use crate::optimizer::genetic::GeneticOpt;

#[derive(Clone, Debug)]
pub struct NetworkSignal {
    pub entry: bool,
    pub exit: bool
}

pub struct Strategy<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub base_net: T,
    pub feats: Vec<Box<dyn Feature>>,
    pub actions: A,
    pub penalties: P,
    pub stop_conds: StopConds,
    pub opt: GeneticOpt,
    pub entry_ptr: NodePtr,
    pub exit_ptr: NodePtr,
    pub stop_loss: f64,
    pub take_profit: f64,
    pub max_hold_time: usize
}

pub fn net_signals<T: Network>(
    net: &mut T,
    entry_ptr: &NodePtr,
    exit_ptr: &NodePtr,
    feat_matrix: &Array2<f64>,
    delay: usize
) -> Vec<NetworkSignal> {
    let n_rows = feat_matrix.nrows();
    let mut signals = Vec::with_capacity(n_rows);

    for _ in 0..delay {
        signals.push(NetworkSignal { entry: false, exit: false });
    }

    net.reset_state();

    for row in delay..n_rows {
        let feat_row = feat_matrix.row(row - delay);
        net.eval(feat_row.as_slice().unwrap());

        let entry_value = net.node_value(entry_ptr);
        let exit_value = net.node_value(exit_ptr);

        signals.push(NetworkSignal {
            entry: entry_value,
            exit: exit_value
        });
    }

    signals
}
