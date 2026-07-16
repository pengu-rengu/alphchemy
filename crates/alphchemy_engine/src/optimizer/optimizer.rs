use rand::rngs::StdRng;
use serde::Serialize;
use crate::actions::actions::Action;
use crate::experiment::backtest::BacktestMetric;
#[cfg(test)]
use mockall::automock;

pub trait Scorer {
    fn score(&self, seq: &[Action]) -> f64;
}

impl<T> Scorer for T
where
    T: Fn(&[Action]) -> f64
{
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

    fn best_score(&self, scores: &[f64]) -> Option<(usize, f64)> {
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
    fn _update_scores<D>(&mut self, deps: &D, train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> Scores
    where
        D: POStateDeps
    {
        self.scores = deps.score_population(&self.pop, train_scorer);

        let (train_best_idx, train) = match deps.best_score(&self.scores) {
            Some(result) => result,
            None => return Scores { train: 0.0, val: 0.0, train_best_idx: 0, val_best_idx: 0 }
        };

        let val_scores = deps.score_population(&self.pop, val_scorer);

        let (val_best_idx, val) = match deps.best_score(&val_scores) {
            Some(result) => result,
            None => return Scores { train: 0.0, val: 0.0, train_best_idx: 0, val_best_idx: 0 }
        };

        Scores {
            train,
            val,
            train_best_idx,
            val_best_idx
        }
    }

    fn _update_state<D>(&mut self, deps: &D, train_scorer: &dyn Scorer, val_scorer: &dyn Scorer)
    where
        D: POStateDeps
    {
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
    use hegel::TestCase;
    use hegel::generators::{booleans, sampled_from};
    use mockall::Sequence;
    use mockall::predicate::{always, eq, in_iter};
    use rand::SeedableRng;
    use crate::test_utils::{gen_f64, gen_usize, gen_usize_with_max, gen_usize_with_min, gen_vec};

    #[hegel::composite]
    pub fn gen_action_seq(tc: TestCase, len: usize) -> Vec<Action> {
        let actions = vec![Action::NextFeat, Action::NextThreshold, Action::SetFeat];
        tc.draw(gen_vec(sampled_from(actions), len))
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
    pub fn gen_po_state(tc: TestCase) -> POState {
        let pop_size = tc.draw(gen_usize_with_max(4)) + 1;
        let seq_len = tc.draw(gen_usize_with_max(4)) + 1;
        let mut pop = Vec::with_capacity(pop_size);

        for _ in 0..pop_size {
            pop.push(tc.draw(gen_action_seq(seq_len)));
        }

        let scores = tc.draw(gen_vec(gen_f64(), pop_size));
        let seed = tc.draw(gen_usize()) as u64;
        let rng = StdRng::seed_from_u64(seed);

        POState {
            pop,
            scores,
            iters_state: ItersState::default(),
            rng
        }
    }

    #[hegel::test]
    fn test_patience_exceeded(tc: TestCase) {
        let iters = tc.draw(gen_usize());
        let last_iter = tc.draw(gen_usize_with_max(iters));
        let patience = tc.draw(gen_usize());
        let score = tc.draw(gen_f64());
        let improvements = vec![Improvement { iter: last_iter, score }];

        let exceeded = StopCondsDepsImpl.patience_exceeded(&improvements, iters, patience);
        let empty_exceeded = StopCondsDepsImpl.patience_exceeded(&[], iters, patience);

        assert_eq!(exceeded, iters - last_iter > patience);
        assert!(!empty_exceeded);
    }

    #[hegel::test]
    fn test_should_stop(tc: TestCase) {
        let stop_conds = tc.draw(gen_stop_conds());
        let max_iters = stop_conds.max_iters;
        let train_patience = stop_conds.train_patience;
        let val_patience = stop_conds.val_patience;

        tc.assume(train_patience != val_patience);

        let exceeded_iters = tc.draw(gen_usize_with_min(max_iters));
        let capped_iters = tc.draw(gen_usize_with_max(max_iters - 1));
        let max_state = ItersState { iters: exceeded_iters, ..ItersState::default() };
        let capped_state = ItersState { iters: capped_iters, ..ItersState::default() };

        let train_patience_exceeded = tc.draw(booleans());
        let val_patience_exceeded = tc.draw(booleans());

        let mut mock_deps = MockStopCondsDeps::new();

        let in_iters = in_iter(vec![exceeded_iters, capped_iters]);
        let eq_train_patience = eq(train_patience);

        let train_patience_dep = mock_deps.expect_patience_exceeded().times(2);
        let train_patience_dep = train_patience_dep.with(always(), in_iters.clone(), eq_train_patience);
        train_patience_dep.return_const(train_patience_exceeded);

        let eq_val_patience = eq(val_patience);

        let val_patience_dep = mock_deps.expect_patience_exceeded().times(2);
        let val_patience_dep = val_patience_dep.with(always(), in_iters, eq_val_patience);
        val_patience_dep.return_const(val_patience_exceeded);

        assert!(stop_conds._should_stop(&mock_deps, &max_state));
        assert_eq!(stop_conds._should_stop(&mock_deps, &capped_state), train_patience_exceeded || val_patience_exceeded);
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

    #[hegel::test]
    fn test_best_score(tc: TestCase) {
        let len = tc.draw(gen_usize_with_max(9)) + 1;
        let best_idx = tc.draw(gen_usize_with_max(len - 1));
        let mut scores = tc.draw(gen_vec(gen_f64(), len));
        scores[best_idx] = 101.0;

        let result = POStateDepsImpl.best_score(&scores);

        assert_eq!(result, Some((best_idx, 101.0)));
        assert_eq!(POStateDepsImpl.best_score(&[]), None);
    }

    #[hegel::test]
    fn test_update_train_improvements(tc: TestCase) {
        let iters = tc.draw(gen_usize());
        let train_score = tc.draw(gen_f64());
        let mut state = ItersState { iters, ..ItersState::default() };

        POStateDepsImpl.update_train_improvements(&mut state, train_score);

        assert_eq!(state.train_improvements.len(), 1);
        assert_eq!(state.train_improvements[0].iter, iters);
        assert_eq!(state.train_improvements[0].score, train_score);
        assert_eq!(state.best_train_score, train_score);
    }

    #[hegel::test]
    fn test_update_val_improvements(tc: TestCase) {
        let iters = tc.draw(gen_usize());
        let val_score = tc.draw(gen_f64());
        let mut state = ItersState { iters, ..ItersState::default() };

        POStateDepsImpl.update_val_improvements(&mut state, val_score);

        assert_eq!(state.val_improvements.len(), 1);
        assert_eq!(state.val_improvements[0].iter, iters);
        assert_eq!(state.val_improvements[0].score, val_score);
        assert_eq!(state.best_val_score, val_score);
    }

    #[hegel::test]
    fn test_update_scores(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        tc.assume(state.pop.len() > 1);

        let pop_len = state.pop.len();
        let mut train_scores = vec![0.0; pop_len];
        train_scores[0] = 1.0;
        let mut val_scores = vec![0.0; pop_len];
        val_scores[1] = 2.0;

        let mut mock_deps = MockPOStateDeps::new();
        let mut sequence = Sequence::new();

        let train_scores_dep = mock_deps.expect_score_population().times(1);
        let train_scores_dep = train_scores_dep.in_sequence(&mut sequence);
        train_scores_dep.return_const(train_scores.clone());

        let train_best_dep = mock_deps.expect_best_score().times(1);
        let train_best_dep = train_best_dep.with(eq(train_scores.clone()));
        let train_best_dep = train_best_dep.in_sequence(&mut sequence);
        train_best_dep.return_const(Some((0, 1.0)));

        let val_scores_dep = mock_deps.expect_score_population().times(1);
        let val_scores_dep = val_scores_dep.in_sequence(&mut sequence);
        val_scores_dep.return_const(val_scores.clone());

        let val_best_dep = mock_deps.expect_best_score().times(1);
        let val_best_dep = val_best_dep.with(eq(val_scores));
        let val_best_dep = val_best_dep.in_sequence(&mut sequence);
        val_best_dep.return_const(Some((1, 2.0)));

        let scores = state._update_scores(&mock_deps, &score_actions, &score_actions);

        assert_eq!(state.scores, train_scores);
        assert_eq!((scores.train, scores.val, scores.train_best_idx, scores.val_best_idx), (1.0, 2.0, 0, 1));
    }

    #[hegel::test]
    fn test_update_state(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        tc.assume(state.pop.len() > 1);
        tc.assume(state.pop[0] != state.pop[1]);

        let previous_iters = tc.draw(gen_usize());
        state.iters_state.iters = previous_iters;
        let expected_train_seq = state.pop[0].clone();
        let expected_val_seq = state.pop[1].clone();
        let scores = Scores { train: 1.0, val: 2.0, train_best_idx: 0, val_best_idx: 1 };
        let mut mock_deps = MockPOStateDeps::new();

        let update_scores_dep = mock_deps.expect_update_scores().times(1);
        update_scores_dep.return_const(scores);

        let eq_train_score = eq(1.0);
        let train_dep = mock_deps.expect_update_train_improvements().times(1);
        let train_dep = train_dep.with(always(), eq_train_score);
        train_dep.return_const(());

        let eq_val_score = eq(2.0);
        let val_dep = mock_deps.expect_update_val_improvements().times(1);
        let val_dep = val_dep.with(always(), eq_val_score);
        val_dep.return_const(());

        state._update_state(&mock_deps, &score_actions, &score_actions);

        assert_eq!(state.iters_state.iters, previous_iters + 1);
        assert_eq!((&state.iters_state.best_train_seq, &state.iters_state.best_val_seq), (&expected_train_seq, &expected_val_seq));
    }
}
