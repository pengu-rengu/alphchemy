use rand::rngs::StdRng;
use serde::Serialize;
use crate::actions::actions::Action;
use crate::experiment::backtest::BacktestMetric;

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
impl ItersState {
    pub fn update_train_improvements(&mut self, train_score: f64) {
        self.train_improvements.push(Improvement {
            iter: self.iters,
            score: train_score
        });
        self.best_train_score = train_score;
    }

    pub fn update_val_improvements(&mut self, val_score: f64) {
        self.val_improvements.push(Improvement {
            iter: self.iters,
            score: val_score
        });
        self.best_val_score = val_score;
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
        if state.iters >= self.max_iters {
            return true
        }

        if deps.patience_exceeded(&state.train_improvements, state.iters, self.train_patience) {
            return true
        }

        if deps.patience_exceeded(&state.val_improvements, state.iters, self.val_patience) {
            return true
        }

        false
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

trait POStateDeps {
    fn score_population<T>(&self, pop: &[Vec<Action>], score_fn: &T) -> Vec<f64>
    where
        T: Fn(&[Action]) -> f64
    {
        let pop_len = pop.len();
        let mut scores = Vec::with_capacity(pop_len);

        for seq in pop {
            let score = score_fn(seq);
            scores.push(score);
        }

        scores
    }

    fn best_score(&self, scores: &[f64]) -> Option<(usize, f64)> {
        let compare_scores = |(_, score_a): &(usize, &f64), (_, score_b): &(usize, &f64)| {
            score_a.total_cmp(score_b)
        };
        let score_iter = scores.iter();
        let enumerated_scores = score_iter.enumerate();
        let maybe_best = enumerated_scores.max_by(compare_scores);

        maybe_best.map(|(idx, score)| (idx, *score))
    }

    fn update_scores<T, V>(&self, state: &mut POState, train_fn: &T, val_fn: &V) -> Scores
    where
        T: Fn(&[Action]) -> f64,
        V: Fn(&[Action]) -> f64
    {
        state._update_scores(&POStateDepsImpl, train_fn, val_fn)
    }

    fn update_train_improvements(&self, state: &mut ItersState, train_score: f64) {
        state.update_train_improvements(train_score);
    }

    fn update_val_improvements(&self, state: &mut ItersState, val_score: f64) {
        state.update_val_improvements(val_score);
    }
}

struct POStateDepsImpl;
impl POStateDeps for POStateDepsImpl {}

impl POState {
    fn _update_scores<T, V, D>(&mut self, deps: &D, train_fn: &T, val_fn: &V) -> Scores
    where
        T: Fn(&[Action]) -> f64,
        V: Fn(&[Action]) -> f64,
        D: POStateDeps
    {
        self.scores = deps.score_population(&self.pop, train_fn);

        let (train_best_idx, train) = match deps.best_score(&self.scores) {
            Some(result) => result,
            None => return Scores { train: 0.0, val: 0.0, train_best_idx: 0, val_best_idx: 0 }
        };

        let val_scores = deps.score_population(&self.pop, val_fn);

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

    fn _update_state<T, V, D>(&mut self, deps: &D, train_fn: &T, val_fn: &V)
    where
        T: Fn(&[Action]) -> f64,
        V: Fn(&[Action]) -> f64,
        D: POStateDeps
    {
        self.iters_state.iters += 1;

        let scores = deps.update_scores(self, train_fn, val_fn);

        if scores.train > self.iters_state.best_train_score {
            deps.update_train_improvements(&mut self.iters_state, scores.train);
            self.iters_state.best_train_seq = self.pop[scores.train_best_idx].clone();
        }

        if scores.val > self.iters_state.best_val_score {
            deps.update_val_improvements(&mut self.iters_state, scores.val);
            self.iters_state.best_val_seq = self.pop[scores.val_best_idx].clone();
        }
    }

    pub fn update_state<T, V>(&mut self, train_fn: &T, val_fn: &V)
    where
        T: Fn(&[Action]) -> f64,
        V: Fn(&[Action]) -> f64
    {
        self._update_state(&POStateDepsImpl, train_fn, val_fn);
    }
}
