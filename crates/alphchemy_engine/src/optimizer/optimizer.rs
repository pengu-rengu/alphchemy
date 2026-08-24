use serde::Serialize;
use crate::actions::actions::Action;
use crate::experiment::backtest::BacktestMetric;
#[cfg(test)]
use mockall::automock;

pub trait Scorer {
    fn score(&self, seq: &[Action]) -> f64;
}

impl<T> Scorer for T where T: Fn(&[Action]) -> f64 {
    fn score(&self, seq: &[Action]) -> f64 {
        self(seq)
    }
}

#[derive(Clone, Debug, Serialize)]
pub struct Objective {
    pub metric: BacktestMetric,
    pub weight: f64
}

#[derive(Clone, Debug)]
pub struct Improvement {
    pub iter: usize,
    pub score: f64
}

#[derive(Clone, Debug)]
pub struct Iteration {
    pub train_score: f64,
    pub val_score: f64,
    pub best_seq: Vec<Action>
}

#[derive(Clone, Debug)]
pub struct ItersState {
    pub iters: usize,
    pub train_improvements: Vec<Improvement>,
    pub val_improvements: Vec<Improvement>,
    pub best_train_seq: Vec<Action>,
    pub best_val_seq: Vec<Action>,
    pub best_train_score: f64,
    pub best_val_score: f64
}

impl Default for ItersState {
    fn default() -> Self {
        Self {
            iters: 0,
            train_improvements: Vec::new(),
            val_improvements: Vec::new(),
            best_train_seq: Vec::new(),
            best_val_seq: Vec::new(),
            best_train_score: f64::NEG_INFINITY,
            best_val_score: f64::NEG_INFINITY
        }
    }
}

#[cfg_attr(test, automock)]
trait ItersStateDeps {
    fn train_improvement(&self, state: &mut ItersState, iter: &Iteration) {
        let train_score = iter.train_score;
        state.train_improvements.push(Improvement {
            iter: state.iters,
            score: train_score
        });
        state.best_train_score = train_score;
        state.best_train_seq = iter.best_seq.clone();
    }

    fn val_improvement(&self, state: &mut ItersState, iter: &Iteration) {
        let val_score = iter.val_score;
        state.val_improvements.push(Improvement {
            iter: state.iters,
            score: val_score
        });
        state.best_val_score = val_score;
        state.best_val_seq = iter.best_seq.clone();
    }
}

struct ItersStateDepsImpl;
impl ItersStateDeps for ItersStateDepsImpl {}

impl ItersState {
    fn _update<T>(&mut self, deps: &T, iter: &Iteration) where T: ItersStateDeps {
        self.iters += 1;

        let train_score = iter.train_score;
        let val_score = iter.val_score;

        if train_score > self.best_train_score {
            deps.train_improvement(self, iter);
        }

        if val_score > self.best_val_score {
            deps.val_improvement(self, iter);
        }
    }

    pub fn update(&mut self, iter: &Iteration) {
        self._update(&ItersStateDepsImpl, iter);
    }
}



#[derive(Clone, Debug, Serialize)]
pub struct StopConds {
    pub max_iters: usize,
    pub train_patience: usize,
    pub val_patience: usize
}

#[cfg_attr(test, automock)]
trait StopCondsDeps {
    fn patience_exceeded(&self, improvements: &[Improvement], iters: usize, patience: usize) -> bool {
        match improvements.last() {
            Some(last) => iters - last.iter > patience,
            None => false
        }
    }
}

struct StopCondsDepsImpl;
impl StopCondsDeps for StopCondsDepsImpl {}

impl StopConds {
    fn _should_stop<T>(&self, deps: &T, state: &ItersState) -> bool where T: StopCondsDeps {
        let train_patience_exceeded = deps.patience_exceeded(&state.train_improvements, state.iters, self.train_patience);
        let val_patience_exceeded = deps.patience_exceeded(&state.val_improvements, state.iters, self.val_patience);

        state.iters >= self.max_iters || train_patience_exceeded || val_patience_exceeded
    }

    pub fn should_stop(&self, state: &ItersState) -> bool {
        self._should_stop(&StopCondsDepsImpl, state)
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use alphchemy_test_utils::{gen_f64, gen_usize, gen_usize_with_max, gen_usize_with_min, gen_vec};
    use hegel::generators::{sampled_from, booleans, hashsets};
    use hegel::TestCase;
    use mockall::predicate::always;

    #[hegel::composite]
    pub fn gen_actions_list(tc: TestCase) -> Vec<Action> {
        let action_gen = sampled_from(&[Action::NextFeat, Action::NextThreshold, Action::SetFeat, Action::NextNode, Action::SelectNode, Action::NextGate, Action::SetFeat, Action::SetThreshold, Action::SetGate, Action::SetIn1Idx, Action::SetIn2Idx, Action::SetTrueIdx, Action::SetFalseIdx, Action::SetRefIdx, Action::NewInput, Action::NewGate, Action::NewBranch, Action::NewRef]);
        tc.draw(hashsets(action_gen).min_size(1)).into_iter().collect()
    }

    #[hegel::composite]
    pub fn gen_action_seq(tc: TestCase, len: usize, maybe_actions_list: Option<&[Action]>) -> Vec<Action> {
        let owned_actions_list;
        let actions_list = match maybe_actions_list {
            Some(list) => list,
            None => {
                owned_actions_list = tc.draw(gen_actions_list());
                &owned_actions_list
            }
        };
        let action_gen = sampled_from(actions_list);
        tc.draw(gen_vec(action_gen, len))
    }

    #[hegel::composite]
    pub fn gen_stop_conds(tc: TestCase) -> StopConds {
        let max_iters = tc.draw(gen_usize_with_min(1));

        StopConds { max_iters, train_patience: tc.draw(gen_usize()), val_patience: tc.draw(gen_usize()) }
    }

    #[hegel::composite]
    fn gen_iteration(tc: TestCase) -> Iteration {
        let seq_len = tc.draw(gen_usize_with_min(1));

        Iteration {
            train_score: tc.draw(gen_f64()),
            val_score: tc.draw(gen_f64()),
            best_seq: tc.draw(gen_action_seq(seq_len, None))
        }
    }

    mod patience_exceeded_tests {
        use super::*;

        #[hegel::composite]
        fn gen_context(tc: TestCase, exceeded: Option<bool>, empty_imps: bool) -> bool {
            let patience = tc.draw(gen_usize());
            let last_iter = tc.draw(gen_usize());
            let iter = last_iter + if exceeded.unwrap_or_else(|| tc.draw(booleans())) {
                tc.draw(gen_usize_with_min(patience)) + 1
            } else {
                tc.draw(gen_usize_with_max(patience))
            };

            let improvements = if empty_imps { vec![] } else {
                vec![Improvement {
                    iter: last_iter,
                    score: tc.draw(gen_f64())
                }]
            };

            StopCondsDepsImpl.patience_exceeded(&improvements, iter, patience)
        }

        #[hegel::test]
        fn test_patience_exceeded(tc: TestCase) {
            let result = tc.draw(gen_context(Some(true), false));
            assert!(result);
        }

        #[hegel::test]
        fn test_patience_not_exceeded(tc: TestCase) {
            let result = tc.draw(gen_context(Some(false), false));
            assert!(!result);
        }

        #[hegel::test]
        fn test_patience_exceeded_empty_imps(tc: TestCase) {
            let result = tc.draw(gen_context(None, true));
            assert!(!result);
        }
    }

    mod should_stop_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            result: bool,
            patience_exceeded: bool
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, exceed_max_iters: bool) -> TestContext {
            let stop_conds = tc.draw(gen_stop_conds());
            let iters = tc.draw(if exceed_max_iters {
                gen_usize_with_min(stop_conds.max_iters) 
            } else {
                gen_usize_with_max(stop_conds.max_iters - 1)
            });
            let iters_state = ItersState {iters, ..ItersState::default() };

            let exceed_train_patience = tc.draw(booleans());
            let exceed_val_patience = tc.draw(booleans());

            let mut mock_deps = MockStopCondsDeps::new();

            mock_deps.expect_patience_exceeded()
                .times(1)
                .return_const(exceed_train_patience);

            mock_deps.expect_patience_exceeded()
                .times(1)
                .return_const(exceed_val_patience);

            let result = stop_conds._should_stop(&mock_deps, &iters_state);

            TestContext { result, patience_exceeded: exceed_train_patience || exceed_val_patience }
        }

        #[hegel::test]
        fn test_should_stop_max_iters(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result);
        }

        #[hegel::test]
        fn test_should_stop_patience(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, ctx.patience_exceeded);
        }
    }

    #[hegel::test]
    fn test_train_improvement(tc: TestCase) {
        let iters = tc.draw(gen_usize());
        let iteration = tc.draw(gen_iteration());
        let mut state = ItersState { iters, ..ItersState::default() };

        ItersStateDepsImpl.train_improvement(&mut state, &iteration);

        assert_eq!(state.train_improvements.len(), 1);
        assert_eq!(state.train_improvements[0].iter, iters);
        assert_eq!(state.train_improvements[0].score, iteration.train_score);
        assert_eq!(state.best_train_score, iteration.train_score);
        assert_eq!(state.best_train_seq, iteration.best_seq);
    }

    #[hegel::test]
    fn test_val_improvement(tc: TestCase) {
        let iters = tc.draw(gen_usize());
        let iteration = tc.draw(gen_iteration());
        let mut state = ItersState { iters, ..ItersState::default() };

        ItersStateDepsImpl.val_improvement(&mut state, &iteration);

        assert_eq!(state.val_improvements.len(), 1);
        assert_eq!(state.val_improvements[0].iter, iters);
        assert_eq!(state.val_improvements[0].score, iteration.val_score);
        assert_eq!(state.best_val_score, iteration.val_score);
        assert_eq!(state.best_val_seq, iteration.best_seq);
    }

    mod update_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            state: ItersState,
            iteration: Iteration,
            previous_state: ItersState
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, train_improved: bool, val_improved: bool) -> TestContext {
            let iters = tc.draw(gen_usize());
            let best_train_score = tc.draw(gen_f64());
            let best_val_score = tc.draw(gen_f64());
            let train_seq_len = tc.draw(gen_usize_with_min(1));
            let val_seq_len = tc.draw(gen_usize_with_min(1));
            let best_train_seq = tc.draw(gen_action_seq(train_seq_len, None));
            let best_val_seq = tc.draw(gen_action_seq(val_seq_len, None));
            let mut state = ItersState {
                iters,
                best_train_seq,
                best_val_seq,
                best_train_score,
                best_val_score,
                ..ItersState::default()
            };
            let previous_state = state.clone();
            let mut iteration = tc.draw(gen_iteration());
            iteration.train_score = if train_improved { best_train_score + 1.0 } else { best_train_score };
            iteration.val_score = if val_improved { best_val_score + 1.0 } else { best_val_score };

            let mut mock_deps = MockItersStateDeps::new();

            mock_deps.expect_train_improvement()
                .times(if train_improved { 1 } else { 0 })
                .with(always(), always())
                .returning_st(|state, iteration| {
                    ItersStateDepsImpl.train_improvement(state, iteration);
                });

            mock_deps.expect_val_improvement()
                .times(if val_improved { 1 } else { 0 })
                .with(always(), always())
                .returning_st(|state, iteration| {
                    ItersStateDepsImpl.val_improvement(state, iteration);
                });

            state._update(&mock_deps, &iteration);

            TestContext { state, iteration, previous_state }
        }

        #[hegel::test]
        fn test_update_both_improved(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, true));

            assert_eq!(ctx.state.iters, ctx.previous_state.iters + 1);
            assert_eq!(ctx.state.train_improvements.len(), 1);
            assert_eq!(ctx.state.val_improvements.len(), 1);
            assert_eq!(ctx.state.best_train_score, ctx.iteration.train_score);
            assert_eq!(ctx.state.best_val_score, ctx.iteration.val_score);
            assert_eq!(ctx.state.best_train_seq, ctx.iteration.best_seq);
            assert_eq!(ctx.state.best_val_seq, ctx.iteration.best_seq);
        }

        #[hegel::test]
        fn test_update_train_improved(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, false));

            assert_eq!(ctx.state.iters, ctx.previous_state.iters + 1);
            assert_eq!(ctx.state.train_improvements.len(), 1);
            assert!(ctx.state.val_improvements.is_empty());
            assert_eq!(ctx.state.best_train_score, ctx.iteration.train_score);
            assert_eq!(ctx.state.best_train_seq, ctx.iteration.best_seq);
            assert_eq!(ctx.state.best_val_score, ctx.previous_state.best_val_score);
            assert_eq!(ctx.state.best_val_seq, ctx.previous_state.best_val_seq);
        }

        #[hegel::test]
        fn test_update_val_improved(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, true));

            assert_eq!(ctx.state.iters, ctx.previous_state.iters + 1);
            assert!(ctx.state.train_improvements.is_empty());
            assert_eq!(ctx.state.val_improvements.len(), 1);
            assert_eq!(ctx.state.best_train_score, ctx.previous_state.best_train_score);
            assert_eq!(ctx.state.best_train_seq, ctx.previous_state.best_train_seq);
            assert_eq!(ctx.state.best_val_score, ctx.iteration.val_score);
            assert_eq!(ctx.state.best_val_seq, ctx.iteration.best_seq);
        }

        #[hegel::test]
        fn test_update_not_improved(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, false));

            assert_eq!(ctx.state.iters, ctx.previous_state.iters + 1);
            assert!(ctx.state.train_improvements.is_empty());
            assert!(ctx.state.val_improvements.is_empty());
            assert_eq!(ctx.state.best_train_score, ctx.previous_state.best_train_score);
            assert_eq!(ctx.state.best_val_score, ctx.previous_state.best_val_score);
            assert_eq!(ctx.state.best_train_seq, ctx.previous_state.best_train_seq);
            assert_eq!(ctx.state.best_val_seq, ctx.previous_state.best_val_seq);
        }
    }
}
