use crate::network::network::{Network, NodePtr, Penalties};
use crate::features::features::{Feature, TimestampedTable};
use crate::actions::actions::Actions;
use crate::optimizer::optimizer::StopConds;
use crate::optimizer::genetic::GeneticOpt;
use serde_json::{Value, json};
#[cfg(test)]
use mockall::automock;

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

#[cfg_attr(test, automock)]
trait StrategyDeps<T: Network> {
    fn reset_state(&self, net: &mut T) {
        net.reset_state();
    }

    fn eval(&self, net: &mut T, feat_table: &TimestampedTable, row: usize) {
        net.eval(feat_table, row);
    }

    fn node_value(&self, net: &T, node_ptr: &NodePtr) -> bool {
        net.node_value(node_ptr)
    }
}

struct StrategyDepsImpl;
impl<T: Network> StrategyDeps<T> for StrategyDepsImpl {}

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

    fn _net_signals<D>(&self, deps: &D, net: &mut T, feat_table: &TimestampedTable, start_idx: usize, end_idx: usize, delay: usize) -> Vec<NetSignals> where D: StrategyDeps<T> {
        let n_rows = end_idx - start_idx + 1;
        let mut signals = Vec::with_capacity(n_rows);

        for _ in 0..delay {
            signals.push( NetSignals {
                entry: false,
                exit: false
            });
        }

        deps.reset_state(net);

        for i in delay..n_rows {
            let row_idx = start_idx + i - delay;
            deps.eval(net, feat_table, row_idx);

            let entry = deps.node_value(net, &self.entry_ptr);
            let exit = deps.node_value(net, &self.exit_ptr);
            let new_signals = NetSignals {
                entry,
                exit
            };
            signals.push(new_signals);
        }

        signals
    }

    pub fn net_signals(&self, net: &mut T, feat_table: &TimestampedTable, start_idx: usize, end_idx: usize, delay: usize) -> Vec<NetSignals> {
        self._net_signals(&StrategyDepsImpl, net, feat_table, start_idx, end_idx, delay)
    }
}
