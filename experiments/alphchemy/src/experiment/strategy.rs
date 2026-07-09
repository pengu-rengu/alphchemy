use crate::network::network::{Network, NodePtr, Penalties};
use crate::features::features::{Feature, TimestampedTable};
use crate::actions::actions::Actions;
use crate::optimizer::optimizer::StopConds;
use crate::optimizer::genetic::GeneticOpt;
use serde_json::{Value, json};

#[derive(Clone, Debug)]
pub struct NetSignals {
    pub entry: bool,
    pub exit: bool
}

pub struct Strategy<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub base_net: T,
    pub feats: Vec<Feature>,
    pub actions: A,
    pub penalties: P,
    pub stop_conds: StopConds,
    pub opt: GeneticOpt,
    pub entry_ptr: NodePtr,
    pub exit_ptr: NodePtr,
    pub stop_loss: f64,
    pub take_profit: f64,
    pub max_hold_time: usize,
    pub qty: f64
}

impl<T: Network, P: Penalties<T>, A: Actions<T>> Strategy<T, P, A> {
    pub fn to_json(&self) -> Value {
        json!({
            "base_net": self.base_net.to_json(),
            "feats": self.feats,
            "actions": self.actions.to_json(),
            "penalties": self.penalties.to_json(),
            "stop_conds": self.stop_conds,
            "opt": self.opt.to_json(),
            "entry_ptr": self.entry_ptr,
            "exit_ptr": self.exit_ptr,
            "stop_loss": self.stop_loss,
            "take_profit": self.take_profit,
            "max_hold_time": self.max_hold_time,
            "qty": self.qty
        })
    }
}

pub fn net_signals<T: Network>(net: &mut T, entry_ptr: &NodePtr, exit_ptr: &NodePtr, feat_table: &TimestampedTable, start_idx: usize, end_idx: usize, delay: usize) -> Vec<NetSignals> {
    let n_rows = end_idx - start_idx + 1;
    let mut signals = Vec::with_capacity(n_rows);

    for _ in 0..delay {
        signals.push( NetSignals {
            entry: false,
            exit: false
        });
    }

    net.reset_state();

    for i in delay..n_rows {
        let row_idx = start_idx + i - delay;
        net.eval(feat_table, row_idx);

        let entry = net.node_value(entry_ptr);
        let exit = net.node_value(exit_ptr);
        let new_signals = NetSignals {
            entry,
            exit
        };
        signals.push(new_signals);
    }

    signals
}
