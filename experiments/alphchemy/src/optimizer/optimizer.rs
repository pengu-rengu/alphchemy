use rand::rngs::StdRng;
use serde::Serialize;
use crate::utils::compare_f64;
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

impl StopConds {
    pub fn should_stop(&self, state: &ItersState) -> bool {
        if state.iters >= self.max_iters {
            return true
        }

        if let Some(last) = state.train_improvements.last() {
            if state.iters - last.iter > self.train_patience {
                return true
            }
        }

        if let Some(last) = state.val_improvements.last() {
            if state.iters - last.iter > self.val_patience {
                return true
            }
        }

        false
    }
}

#[derive(Clone, Debug)]
pub struct POState {
    pub pop: Vec<Vec<Action>>,
    pub scores: Vec<f64>,
    pub iters_state: ItersState,
    pub rng: StdRng
}

impl POState {
    pub fn update_scores<T, V>(&mut self, train_fn: &T, val_fn: &V) -> Scores
    where
        T: Fn(&[Action]) -> f64,
        V: Fn(&[Action]) -> f64
    {
        self.scores = self.pop.iter().map(|seq| train_fn(seq)).collect();

        let (train_best_idx, &train) = match self.scores.iter().enumerate().max_by(|(_, a), (_, b)| compare_f64(**a, **b))
        {
            Some(result) => result,
            None => return Scores { train: 0.0, val: 0.0, train_best_idx: 0, val_best_idx: 0 }
        };

        let val_scores: Vec<f64> = self.pop.iter().map(|seq| val_fn(seq)).collect();

        let (val_best_idx, &val) = match val_scores.iter().enumerate().max_by(|(_, a), (_, b)| compare_f64(**a, **b))
        {
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

    pub fn update_state<T, V>(&mut self, train_fn: &T, val_fn: &V)
    where
        T: Fn(&[Action]) -> f64,
        V: Fn(&[Action]) -> f64
    {
        self.iters_state.iters += 1;

        let scores = self.update_scores(train_fn, val_fn);

        if scores.train > self.iters_state.best_train_score {
            self.iters_state.update_train_improvements(scores.train);
            self.iters_state.best_train_seq = self.pop[scores.train_best_idx].clone();
        }

        if scores.val > self.iters_state.best_val_score {
            self.iters_state.update_val_improvements(scores.val);
            self.iters_state.best_val_seq = self.pop[scores.val_best_idx].clone();
        }
    }
}
