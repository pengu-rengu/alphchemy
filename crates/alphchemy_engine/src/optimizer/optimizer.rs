use rand::rngs::StdRng;
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
#[derive(Clone, Debug)]
pub struct Scores {
    pub train: f64,
    pub val: f64,
    pub train_best_idx: usize,
    pub val_best_idx: usize
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

#[derive(Clone, Debug)]
pub struct POState {
    pub pop: Vec<Vec<Action>>,
    pub scores: Vec<f64>,
    pub iters_state: ItersState,
    pub rng: StdRng
}

#[cfg_attr(test, automock)]
trait POStateDeps {
    fn score_population(&self, pop: &[Vec<Action>], scorer: &dyn Scorer) -> Vec<f64> {
        let pop_len = pop.len();
        let mut scores = Vec::with_capacity(pop_len);

        for seq in pop {
            let score = scorer.score(seq);
            scores.push(score);
        }

        scores
    }

    fn best_idx_and_score(&self, scores: &[f64]) -> Option<(usize, f64)> {
        let maybe_best = scores.iter().enumerate().max_by(|(_, score_a): &(usize, &f64), (_, score_b): &(usize, &f64)| {
            score_a.total_cmp(score_b)
        });

        maybe_best.map(|(idx, score)| (idx, *score))
    }

    fn update_scores(&self, state: &mut POState, train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> Scores {
        state._update_scores(&POStateDepsImpl, train_scorer, val_scorer)
    }

    fn update_train_improvements(&self, state: &mut ItersState, train_score: f64) {
        state.train_improvements.push(Improvement {
            iter: state.iters,
            score: train_score
        });
        state.best_train_score = train_score;
    }

    fn update_val_improvements(&self, state: &mut ItersState, val_score: f64) {
        state.val_improvements.push(Improvement {
            iter: state.iters,
            score: val_score
        });
        state.best_val_score = val_score;
    }
}

struct POStateDepsImpl;
impl POStateDeps for POStateDepsImpl {}

impl POState {
    fn _update_scores<T>(&mut self, deps: &T, train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> Scores where T: POStateDeps {
        self.scores = deps.score_population(&self.pop, train_scorer);

        let (train_best_idx, train) = match deps.best_idx_and_score(&self.scores) {
            Some(result) => result,
            None => return Scores { train: 0.0, val: 0.0, train_best_idx: 0, val_best_idx: 0 }
        };

        let val_scores = deps.score_population(&self.pop, val_scorer);

        let (val_best_idx, val) = match deps.best_idx_and_score(&val_scores) {
            Some(result) => result,
            None => return Scores { train: 0.0, val: 0.0, train_best_idx: 0, val_best_idx: 0 }
        };

        Scores { train, val,  train_best_idx, val_best_idx }
    }

    fn _update_state<T>(&mut self, deps: &T, train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) where T: POStateDeps {
        self.iters_state.iters += 1;

        let scores = deps.update_scores(self, train_scorer, val_scorer);

        if scores.train > self.iters_state.best_train_score {
            deps.update_train_improvements(&mut self.iters_state, scores.train);
            self.iters_state.best_train_seq = self.pop[scores.train_best_idx].clone();
        }

        if scores.val > self.iters_state.best_val_score {
            deps.update_val_improvements(&mut self.iters_state, scores.val);
            self.iters_state.best_val_seq = self.pop[scores.val_best_idx].clone();
        }
    }

    pub(super) fn update_state(&mut self, train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) {
        self._update_state(&POStateDepsImpl, train_scorer, val_scorer);
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use alphchemy_test_utils::{gen_f64, gen_usize, gen_usize_with_max, gen_usize_with_min, gen_vec, FLOAT_MAX};
    use hegel::generators::{sampled_from, booleans, hashsets};
    use hegel::TestCase;
    use mockall::predicate::{always, eq};
    use rand::SeedableRng;

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
        StopConds {
            max_iters: tc.draw(gen_usize_with_min(1)),
            train_patience: tc.draw(gen_usize()),
            val_patience: tc.draw(gen_usize())
        }
    }

    #[hegel::composite]
    fn gen_scores(tc: TestCase, pop_len: usize) -> Scores {
        Scores {
            train: tc.draw(gen_f64()),
            val: tc.draw(gen_f64()),
            train_best_idx: tc.draw(gen_usize_with_max(pop_len - 1)),
            val_best_idx: tc.draw(gen_usize_with_max(pop_len - 1))
        }
    }

    #[hegel::composite]
    pub fn gen_po_state(tc: TestCase) -> POState {
        let pop_size = tc.draw(gen_usize_with_max(4)) + 1;
        let seq_len = tc.draw(gen_usize_with_max(4)) + 1;
        let mut pop = Vec::with_capacity(pop_size);

        for _ in 0..pop_size {
            pop.push(tc.draw(gen_action_seq(seq_len, None)));
        }

        let scores = tc.draw(gen_vec(gen_f64(), pop_size));
        let seed = tc.draw(gen_usize()) as u64;
        let rng = StdRng::seed_from_u64(seed);

        POState { pop, scores, iters_state: ItersState::default(), rng }
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

            let train_patience_dep = mock_deps.expect_patience_exceeded().times(1);
            train_patience_dep.return_const(exceed_train_patience);

            let val_patience_dep = mock_deps.expect_patience_exceeded().times(1);
            val_patience_dep.return_const(exceed_val_patience);

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

    fn score_actions(seq: &[Action]) -> f64 {
        seq.len() as f64
    }


    #[hegel::test]
    fn test_score_population(tc: TestCase) {
        let state = tc.draw(gen_po_state());
        let scores = POStateDepsImpl.score_population(&state.pop, &score_actions);

        for i in 0..state.pop.len() {
            assert_eq!(scores[i], score_actions(&state.pop[i]));
        }
    }

    mod best_idx_and_score_tests {
        use super::*;

        #[hegel::test]
        fn test_best_score(tc: TestCase) {
            let len = tc.draw(gen_usize_with_min(1));
            let best_idx = tc.draw(gen_usize_with_max(len - 1));
            let mut scores = tc.draw(gen_vec(gen_f64(), len));

            let best_score = tc.draw(gen_f64()) + 1.0 + FLOAT_MAX;
            scores[best_idx] = best_score;

            let result = POStateDepsImpl.best_idx_and_score(&scores);
            assert_eq!(result, Some((best_idx, best_score)));
        }

        #[hegel::test]
        fn test_best_score_empty(_tc: TestCase) {
            let result = POStateDepsImpl.best_idx_and_score(&[]);
            assert_eq!(result, None);
        }
    }

    #[hegel::test]
    fn test_update_train_improvements(tc: TestCase) {
        let iters = tc.draw(gen_usize());
        let train_score = tc.draw(gen_f64());
        let mut iters_state = ItersState { iters, ..ItersState::default() };

        POStateDepsImpl.update_train_improvements(&mut iters_state, train_score);

        assert_eq!(iters_state.train_improvements.len(), 1);
        assert_eq!(iters_state.train_improvements[0].iter, iters);
        assert_eq!(iters_state.train_improvements[0].score, train_score);
        assert_eq!(iters_state.best_train_score, train_score);
    }

    #[hegel::test]
    fn test_update_val_improvements(tc: TestCase) {
        let iters = tc.draw(gen_usize());
        let val_score = tc.draw(gen_f64());
        let mut iters_state = ItersState { iters, ..ItersState::default() };

        POStateDepsImpl.update_val_improvements(&mut iters_state, val_score);

        assert_eq!(iters_state.val_improvements.len(), 1);
        assert_eq!(iters_state.val_improvements[0].iter, iters);
        assert_eq!(iters_state.val_improvements[0].score, val_score);
        assert_eq!(iters_state.best_val_score, val_score);
    }

    #[hegel::test]
    fn test_update_scores(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        let pop_len = state.pop.len();
        let expected_scores = tc.draw(gen_scores(pop_len));
        let train_scores = tc.draw(gen_vec(gen_f64(), pop_len));
        let val_scores = tc.draw(gen_vec(gen_f64(), pop_len));

        let mut mock_deps = MockPOStateDeps::new();

        let train_scores_dep = mock_deps.expect_score_population().times(1);
        train_scores_dep.return_const(train_scores.clone());

        let eq_train_scores = eq(train_scores.clone());

        let train_best_dep = mock_deps.expect_best_idx_and_score().times(1);
        let train_best_dep = train_best_dep.with(eq_train_scores);
        train_best_dep.return_const(Some((expected_scores.train_best_idx, expected_scores.train)));

        let val_scores_dep = mock_deps.expect_score_population().times(1);
        val_scores_dep.return_const(val_scores.clone());

        let eq_val_scores = eq(val_scores.clone());

        let val_best_dep = mock_deps.expect_best_idx_and_score().times(1);
        let val_best_dep = val_best_dep.with(eq_val_scores);
        val_best_dep.return_const(Some((expected_scores.val_best_idx, expected_scores.val)));

        let scores = state._update_scores(&mock_deps, &score_actions, &score_actions);

        assert_eq!(state.scores, train_scores);
        assert_eq!(scores.train, expected_scores.train);
        assert_eq!(scores.val, expected_scores.val);
        assert_eq!(scores.train_best_idx, expected_scores.train_best_idx);
        assert_eq!(scores.val_best_idx, expected_scores.val_best_idx);
    }

    mod update_state_tests {
        use super::*;
        #[hegel::test]
        fn test_update_state(tc: TestCase) {
            let mut state = tc.draw(gen_po_state());
            let pop_len = state.pop.len();
            let scores = tc.draw(gen_scores(pop_len));
            let expected_train_seq = state.pop[scores.train_best_idx].clone();
            let expected_val_seq = state.pop[scores.val_best_idx].clone();
            let prev_iters = state.iters_state.iters;

            let mut mock_deps = MockPOStateDeps::new();

            let update_scores_dep = mock_deps.expect_update_scores().times(1);
            update_scores_dep.return_const(scores.clone());

            let eq_train_score = eq(scores.train);
            let train_dep = mock_deps.expect_update_train_improvements().times(1);
            train_dep.with(always(), eq_train_score).return_const(());

            let eq_val_score = eq(scores.val);
            let val_dep = mock_deps.expect_update_val_improvements().times(1);
            val_dep.with(always(), eq_val_score).return_const(());

            state._update_state(&mock_deps, &score_actions, &score_actions);

            assert_eq!(state.iters_state.iters, prev_iters + 1);
            assert_eq!(&state.iters_state.best_train_seq, &expected_train_seq);
            assert_eq!(&state.iters_state.best_val_seq, &expected_val_seq);
        }
    }
}
