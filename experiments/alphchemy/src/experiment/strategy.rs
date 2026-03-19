use ndarray::Array2;
use serde::Deserialize;

use crate::network::network::{Network, NodePtr, Penalties};
use crate::features::features::Feature;
use crate::actions::actions::Actions;
use crate::optimizer::optimizer::StopConds;
use crate::optimizer::genetic::GeneticOpt;

#[derive(Clone, Debug, Deserialize)]
pub struct EntrySchema {
    pub node_ptr: NodePtr,
    pub position_size: f64,
    pub max_positions: usize
}

#[derive(Clone, Debug, Deserialize)]
pub struct ExitSchema {
    pub node_ptr: NodePtr,
    pub entry_indices: Vec<usize>,
    pub stop_loss: f64,
    pub take_profit: f64,
    pub max_hold_time: usize
}

#[derive(Clone, Debug)]
pub struct NetSignals {
    pub entries: Vec<bool>,
    pub exits: Vec<bool>
}

pub struct Strategy<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub base_net: T,
    pub feats: Vec<Box<dyn Feature>>,
    pub actions: A,
    pub penalties: P,
    pub stop_conds: StopConds,
    pub opt: GeneticOpt,
    pub entry_schemas: Vec<EntrySchema>,
    pub exit_schemas: Vec<ExitSchema>
}

pub fn net_signals<T: Network>(net: &mut T, entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema], feat_matrix: &Array2<f64>, delay: usize) -> Vec<NetSignals> {
    let n_rows = feat_matrix.nrows();
    let n_entries = entry_schemas.len();
    let n_exits = exit_schemas.len();
    let mut signals = Vec::with_capacity(n_rows);

    for _ in 0..delay {
        let default_signal = NetSignals {
            entries: vec![false; n_entries],
            exits: vec![false; n_exits]
        };
        signals.push(default_signal);
    }

    net.reset_state();

    for i in delay..n_rows {
        let row = feat_matrix.row(i - delay);
        let row_slice = row.as_slice().unwrap_or(&[]);
        net.eval(row_slice);

        let entry_value_fn = |entry_schema: &EntrySchema| net.node_value(&entry_schema.node_ptr);
        let entries = entry_schemas.iter().map(entry_value_fn).collect();

        let exit_value_fn = |exit_schema: &ExitSchema| net.node_value(&exit_schema.node_ptr);
        let exits = exit_schemas.iter().map(exit_value_fn).collect();
        
        let new_signals = NetSignals { 
            entries, 
            exits 
        };
        signals.push(new_signals);
    }

    signals
}
