use serde::Deserialize;
use serde_json::Value;
use crate::utils::parse_json;
use crate::actions::actions::Action;

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
    pub best_seq: Vec<Action>,
    pub best_train_score: f64,
    pub best_val_score: f64
}

impl Default for ItersState {
    fn default() -> Self {
        Self {
            iters: 0,
            train_improvements: Vec::new(),
            val_improvements: Vec::new(),
            best_seq: Vec::new(),
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
    pub best_idx: usize
}

#[derive(Clone, Debug, Deserialize)]
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
    pub iters_state: ItersState
}

impl POState {
    pub fn update_scores<T, V>(&mut self, train_fn: &T, val_fn: &V) -> Scores
    where
        T: Fn(&[Action]) -> f64,
        V: Fn(&[Action]) -> f64
    {
        self.scores = self.pop.iter().map(|seq| train_fn(seq)).collect();

        let (best_idx, &train) = self
            .scores
            .iter()
            .enumerate()
            .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
            .unwrap();

        let val = val_fn(&self.pop[best_idx]);

        Scores {
            train,
            val,
            best_idx
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
        }

        if scores.val > self.iters_state.best_val_score {
            self.iters_state.update_val_improvements(scores.val);
            self.iters_state.best_seq = self.pop[scores.best_idx].clone();
        }
    }
}

pub fn parse_stop_conds(json: &Value) -> Result<StopConds, String> {
    let sc = parse_json::<StopConds>(json)?;

    if sc.max_iters == 0 {
        return Err("max_iters must be > 0".to_string());
    }

    Ok(sc)
}
