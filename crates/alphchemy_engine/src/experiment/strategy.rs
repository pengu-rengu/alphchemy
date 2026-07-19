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

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DataRange {
    pub start_idx: usize,
    pub end_idx: usize
}

#[derive(Debug)]
pub struct Strategy<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub base_net: T,
    pub feats: Vec<Feature>,
    pub actions: A,
    pub penalties: P,
    pub stop_conds: StopConds,
    pub opt: GeneticOpt,
    pub entry_ptr: NodePtr,
    pub exit_ptr: NodePtr,
    pub strong_entry: bool,
    pub strong_exit: bool,
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
            "strong_entry": self.strong_entry,
            "strong_exit": self.strong_exit,
            "stop_loss": self.stop_loss,
            "take_profit": self.take_profit,
            "max_hold_time": self.max_hold_time,
            "qty": self.qty
        })
    }

    fn _net_signals<D>(&self, deps: &D, net: &mut T, feat_table: &TimestampedTable, data_range: DataRange, delay: usize) -> Vec<NetSignals> where D: StrategyDeps<T> {
        let start_idx = data_range.start_idx;
        let n_rows = data_range.end_idx - start_idx + 1;
        let mut signals = Vec::with_capacity(n_rows);

        for _ in 0..delay {
            signals.push( NetSignals {
                entry: false,
                exit: false
            });
        }

        deps.reset_state(net);

        for i in delay..n_rows {
            let row_offset = i - delay;
            let row_idx = start_idx + row_offset;
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

    pub fn net_signals(&self, net: &mut T, feat_table: &TimestampedTable, data_range: DataRange, delay: usize) -> Vec<NetSignals> {
        self._net_signals(&StrategyDepsImpl, net, feat_table, data_range, delay)
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use crate::actions::logic_actions::tests::gen_logic_actions;
    use crate::actions::logic_actions::LogicActions;
    use crate::features::features::tests::{gen_feat_table, gen_feats};
    use crate::network::logic_net::tests::{gen_logic_net, gen_logic_penalties};
    use crate::network::logic_net::{LogicNet, LogicPenalties};
    use crate::network::network::tests::gen_node_ptr;
    use crate::optimizer::optimizer::tests::gen_stop_conds;
    use crate::optimizer::optimizer::Objective;
    use crate::test_utils::{
        gen_f64, gen_f64_with_max, gen_usize, gen_usize_between, gen_usize_with_max, gen_vec
    };
    use hegel::generators::booleans;
    use hegel::TestCase;
    use mockall::predicate::{always, eq};
    use std::cell::{Cell, RefCell};
    use std::rc::Rc;

    #[hegel::composite]
    pub fn gen_opt(tc: TestCase, objectives: Option<&[Objective]>) -> GeneticOpt {
        let pop_size = tc.draw(gen_usize_with_max(4)) + 1;
        let seq_len = tc.draw(gen_usize_with_max(4)) + 2;
        let n_elites = tc.draw(gen_usize_with_max(pop_size));
        let tourn_size = tc.draw(gen_usize_with_max(pop_size - 1)) + 1;
        let mut_rate = tc.draw(gen_f64_with_max(1.0, false));
        let cross_rate = tc.draw(gen_f64_with_max(1.0, false));
        let random_seed = tc.draw(gen_usize());
        let opt_objectives = match objectives {
            Some(drawn) => drawn.to_vec(),
            None => Vec::new()
        };

        GeneticOpt {
            pop_size,
            seq_len,
            n_elites,
            mut_rate,
            cross_rate,
            tourn_size,
            objectives: opt_objectives,
            random_seed: Some(random_seed)
        }
    }

    #[hegel::composite]
    pub fn gen_strategy(
        tc: TestCase,
        feat_ids: Option<&[String]>,
        objectives: Option<&[Objective]>
    ) -> Strategy<LogicNet, LogicPenalties, LogicActions> {
        let base_net = tc.draw(gen_logic_net(Some(false), feat_ids));
        let n_nodes = base_net.nodes.len();
        let n_feats = tc.draw(gen_usize_with_max(3)) + 1;
        let feats = tc.draw(gen_feats(n_feats, None));
        let actions = tc.draw(gen_logic_actions(feat_ids, None));
        let penalties = tc.draw(gen_logic_penalties());
        let stop_conds = tc.draw(gen_stop_conds());
        let opt = tc.draw(gen_opt(objectives));
        let entry_ptr = tc.draw(gen_node_ptr(n_nodes, None, false));
        let exit_ptr = tc.draw(gen_node_ptr(n_nodes, None, false));

        Strategy {
            base_net,
            feats,
            actions,
            penalties,
            stop_conds,
            opt,
            entry_ptr,
            exit_ptr,
            strong_entry: tc.draw(booleans()),
            strong_exit: tc.draw(booleans()),
            stop_loss: tc.draw(gen_f64()),
            take_profit: tc.draw(gen_f64()),
            max_hold_time: tc.draw(gen_usize()),
            qty: tc.draw(gen_f64())
        }
    }

    #[hegel::composite]
    pub fn gen_data_range(tc: TestCase, n_rows: usize) -> DataRange {
        let start_idx = tc.draw(gen_usize_with_max(20));
        let last_offset = n_rows - 1;
        let end_idx = start_idx + last_offset;

        DataRange { start_idx, end_idx }
    }

    mod net_signals_tests {
        use super::*;
        #[hegel::test]
        fn test_net_signals(tc: TestCase) {
            let strategy = tc.draw(gen_strategy(None, None));
            tc.assume(strategy.entry_ptr != strategy.exit_ptr);

            let feat_table = tc.draw(gen_feat_table());
            let mut net = tc.draw(gen_logic_net(Some(false), None));
            let n_rows = tc.draw(gen_usize_between(2, 10));
            let delay = tc.draw(gen_usize_with_max(n_rows - 1));
            let data_range = tc.draw(gen_data_range(n_rows));
            let n_evals = n_rows - delay;

            let entry_values = Rc::new(tc.draw(gen_vec(booleans(), n_evals)));
            let exit_values = Rc::new(tc.draw(gen_vec(booleans(), n_evals)));

            let mut mock_deps = MockStrategyDeps::new();

            let reset_state_dep = mock_deps.expect_reset_state().times(1);
            reset_state_dep.return_const(());

            let eval_dep = mock_deps.expect_eval().times(n_evals);
            let eval_dep = eval_dep.with(always(), always(), always());
            eval_dep.return_const(());

            let entry_idx = Rc::new(Cell::new(0));
            let entry_idx_return = Rc::clone(&entry_idx);
            let entry_values_return = Rc::clone(&entry_values);
            let eq_entry_ptr = eq(strategy.entry_ptr.clone());

            let entry_dep = mock_deps.expect_node_value().times(n_evals);
            let entry_dep = entry_dep.with(always(), eq_entry_ptr);
            entry_dep.returning_st(move |_, _| {
                let idx = entry_idx_return.get();
                let value = entry_values_return[idx];
                entry_idx_return.set(idx + 1);
                value
            });

            let exit_idx = Rc::new(Cell::new(0));
            let exit_idx_return = Rc::clone(&exit_idx);
            let exit_values_return = Rc::clone(&exit_values);
            let eq_exit_ptr = eq(strategy.exit_ptr.clone());

            let exit_dep = mock_deps.expect_node_value().times(n_evals);
            let exit_dep = exit_dep.with(always(), eq_exit_ptr);
            exit_dep.returning_st(move |_, _| {
                let idx = exit_idx_return.get();
                let value = exit_values_return[idx];
                exit_idx_return.set(idx + 1);
                value
            });

            let signals =
                strategy._net_signals(&mock_deps, &mut net, &feat_table, data_range, delay);

            assert_eq!(signals.len(), n_rows);

            for signal in signals.iter().take(delay) {
                assert!(!signal.entry);
                assert!(!signal.exit);
            }

            for i in 0..n_evals {
                let signal_idx = delay + i;
                assert_eq!(signals[signal_idx].entry, entry_values[i]);
                assert_eq!(signals[signal_idx].exit, exit_values[i]);
            }
        }

        #[hegel::test]
        fn test_net_signals_row_indices(tc: TestCase) {
            let strategy = tc.draw(gen_strategy(None, None));
            let feat_table = tc.draw(gen_feat_table());
            let mut net = tc.draw(gen_logic_net(Some(false), None));
            let n_rows = tc.draw(gen_usize_between(2, 10));
            let delay = tc.draw(gen_usize_with_max(n_rows - 1));
            let data_range = tc.draw(gen_data_range(n_rows));
            let n_evals = n_rows - delay;

            let eval_rows = Rc::new(RefCell::new(Vec::new()));
            let mut mock_deps = MockStrategyDeps::new();

            let reset_state_dep = mock_deps.expect_reset_state().times(1);
            reset_state_dep.return_const(());

            let eval_rows_return = Rc::clone(&eval_rows);
            let eval_dep = mock_deps.expect_eval().times(n_evals);
            eval_dep.returning_st(move |_, _, row| {
                eval_rows_return.borrow_mut().push(row);
            });

            let node_value_dep = mock_deps.expect_node_value();
            node_value_dep.return_const(false);

            strategy._net_signals(&mock_deps, &mut net, &feat_table, data_range, delay);

            let first_row = data_range.start_idx;
            let past_last_row = first_row + n_evals;
            let expected_rows = (first_row..past_last_row).collect::<Vec<usize>>();
            assert_eq!(*eval_rows.borrow(), expected_rows);
        }

        #[hegel::test]
        fn test_net_signals_delay_exceeds_range(tc: TestCase) {
            let strategy = tc.draw(gen_strategy(None, None));
            let feat_table = tc.draw(gen_feat_table());
            let mut net = tc.draw(gen_logic_net(Some(false), None));
            let n_rows = tc.draw(gen_usize_between(1, 5));
            let delay = tc.draw(gen_usize_between(n_rows, 8));
            let data_range = tc.draw(gen_data_range(n_rows));

            let mut mock_deps = MockStrategyDeps::new();

            let reset_state_dep = mock_deps.expect_reset_state().times(1);
            reset_state_dep.return_const(());
            mock_deps.expect_eval().times(0);
            mock_deps.expect_node_value().times(0);

            let signals =
                strategy._net_signals(&mock_deps, &mut net, &feat_table, data_range, delay);

            // delay >= n_rows yields `delay` placeholders and no evals, so the vec runs past the range.
            assert_eq!(signals.len(), delay);

            for signal in &signals {
                assert!(!signal.entry);
                assert!(!signal.exit);
            }
        }
    }

    mod to_json_tests {
        use super::*;
        #[hegel::test]
        fn test_to_json(tc: TestCase) {
            let strategy = tc.draw(gen_strategy(None, None));

            let value = strategy.to_json();

            assert_eq!(value["base_net"], strategy.base_net.to_json());
            assert_eq!(value["feats"], json!(strategy.feats));
            assert_eq!(value["actions"], strategy.actions.to_json());
            assert_eq!(value["penalties"], strategy.penalties.to_json());
            assert_eq!(value["stop_conds"], json!(strategy.stop_conds));
            assert_eq!(value["opt"], strategy.opt.to_json());
            assert_eq!(value["entry_ptr"], json!(strategy.entry_ptr));
            assert_eq!(value["exit_ptr"], json!(strategy.exit_ptr));
            assert_eq!(value["strong_entry"], json!(strategy.strong_entry));
            assert_eq!(value["strong_exit"], json!(strategy.strong_exit));
            assert_eq!(value["stop_loss"], json!(strategy.stop_loss));
            assert_eq!(value["take_profit"], json!(strategy.take_profit));
            assert_eq!(value["max_hold_time"], json!(strategy.max_hold_time));
            assert_eq!(value["qty"], json!(strategy.qty));
        }
    }
}
