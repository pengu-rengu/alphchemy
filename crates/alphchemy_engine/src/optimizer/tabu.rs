use std::collections::{HashMap, VecDeque};

use rand::{Rng, SeedableRng,
    distr::{Distribution,
        weighted::WeightedIndex
    },
    rngs::StdRng
};
use crate::{
    actions::actions::Action,
    optimizer::optimizer::{Iteration, ItersState, Scorer, StopConds}
};


pub struct TabuOpt {
    pub seq_len: usize,
    pub n_neighbors: usize,
    pub tabu_len: usize,
    pub aspiration: bool,
    pub action_weights: HashMap<Action, f64>,
    pub random_seed: Option<usize>
}

pub struct TabuState {
    pub seq: Vec<Action>,
    pub tabu_list: VecDeque<usize>,
    pub actions_list: Vec<Action>,
    pub iters_state: ItersState,
    pub rng: StdRng,
}

struct Neighbor {
    pub seq: Vec<Action>,
    pub mut_idx: usize,
    pub score: f64
}

trait TabuOptDeps {
    fn create_rng(&self, random_seed: Option<usize>) -> StdRng {
        match random_seed {
            Some(seed) => StdRng::seed_from_u64(seed as u64),
            None => StdRng::from_os_rng()
        }
    }

    fn random_f64(&self, rng: &mut StdRng) -> f64 {
        rng.random::<f64>()
    }

    fn random_usize(&self, rng: &mut StdRng, max: usize) -> usize {
        rng.random_range(0..max)
    }

    fn random_action(&self, actions_list: &[Action], action_weights: &HashMap<Action, f64>, maybe_excluded_action: Option<&Action>, rng: &mut StdRng) -> Result<Action, String> {
        let mut weights = Vec::with_capacity(actions_list.len());

        for action in actions_list {
            let excluded = maybe_excluded_action == Some(action);
            let weight = if excluded { 0.0 } else {
                let maybe_weight = action_weights.get(action);
                maybe_weight.copied().unwrap_or(1.0)
            };
            weights.push(weight);
        }

        let maybe_distribution = WeightedIndex::new(weights);
        let distribution = maybe_distribution.map_err(|_| "No selectable action found".to_string())?;
        let action_idx = distribution.sample(rng);
        Ok(actions_list[action_idx].clone())
    }


    fn initial_state(&self, opt: &TabuOpt, actions_list: &[Action]) -> Result<TabuState, String> {
        opt._initial_state(&TabuOptDepsImpl, actions_list)
    }

    fn neighbor(&self, opt: &TabuOpt, state: &mut TabuState) -> Result<Neighbor, String> {
        opt._neighbor(&TabuOptDepsImpl, state)
    }

    fn get_neighbors(&self, opt: &TabuOpt, state: &mut TabuState) -> Result<Vec<Neighbor>, String> {
        opt._get_neighbors(&TabuOptDepsImpl, state)
    }

    fn score_neighbors(&self, neighbors: &mut [Neighbor], train_scorer: &dyn Scorer) {
        for neighbor in neighbors {
            neighbor.score = train_scorer.score(&neighbor.seq);
        }
    }

    fn best_neighbor_idx(&self, neighbors: &[Neighbor]) -> Result<usize, String> {
        let maybe_best = neighbors.iter().enumerate().max_by(|(_, neighbor_a), (_, neighbor_b)| {
            neighbor_a.score.total_cmp(&neighbor_b.score)
        });
        let maybe_best_idx = maybe_best.map(|(idx, _)| idx);
        maybe_best_idx.ok_or_else(|| {
            format!("No best neighbor found")
        })
    }

    fn new_seq(&self, opt: &TabuOpt, state: &mut TabuState, train_scorer: &dyn Scorer) -> Result<f64, String> {
        opt._new_seq(&TabuOptDepsImpl, state, train_scorer)
    }

    fn update_iters_state(&self, state: &mut TabuState, iter: &Iteration) {
        state.iters_state.update(iter);
    }

    fn update_state(&self, opt: &TabuOpt, state: &mut TabuState, train_score: f64, val_scorer: &dyn Scorer) {
        opt._update_state(&TabuOptDepsImpl, state, train_score, val_scorer);
    }

    fn should_stop(&self, stop_conds: &StopConds, state: &ItersState) -> bool {
        stop_conds.should_stop(state)
    }
}

struct TabuOptDepsImpl;
impl TabuOptDeps for TabuOptDepsImpl {}

impl TabuOpt {
    fn _initial_state<T>(&self, deps: &T, actions_list: &[Action]) -> Result<TabuState, String> where T: TabuOptDeps {
        let mut rng = deps.create_rng(self.random_seed);
        let mut seq = Vec::with_capacity(self.seq_len);

        for _ in 0..self.seq_len {
            let action = deps.random_action(actions_list, &self.action_weights, None, &mut rng)?;
            seq.push(action);
        }

        Ok(TabuState {
            seq,
            tabu_list: VecDeque::new(),
            actions_list: actions_list.to_vec(),
            iters_state: ItersState::default(),
            rng: rng
        })
    }

    fn _neighbor<T>(&self, deps: &T, state: &mut TabuState) -> Result<Neighbor, String> where T: TabuOptDeps  {
        let mut neighbor = state.seq.to_vec();
        let idx = deps.random_usize(&mut state.rng, self.seq_len);
        let maybe_current_action = neighbor.get(idx);
        let current_action = match maybe_current_action {
            Some(action) => action.clone(),
            None => return Err("Index out of bounds".to_string())
        };
        let new_action = deps.random_action(&state.actions_list, &self.action_weights, Some(&current_action), &mut state.rng)?;
        neighbor[idx] = new_action;

        Ok(Neighbor { seq: neighbor, mut_idx: idx, score: 0.0 })
    }

    fn _get_neighbors<T>(&self, deps: &T, state: &mut TabuState) -> Result<Vec<Neighbor>, String> where T: TabuOptDeps {
        let mut neighbors = Vec::<Neighbor>::new();

        for _ in 0..self.n_neighbors {
            let neighbor = deps.neighbor(self, state)?;
            neighbors.push(neighbor);
        }

        Ok(neighbors)
    }

    fn _new_seq<T>(&self, deps: &T, state: &mut TabuState, train_scorer: &dyn Scorer) -> Result<f64, String> where T: TabuOptDeps {
        let mut neighbors = deps.get_neighbors(self, state)?;
        deps.score_neighbors(&mut neighbors, train_scorer);

        let mut best_idx = deps.best_neighbor_idx(&neighbors)?;
        if !(self.aspiration && neighbors[best_idx].score > state.iters_state.best_train_score) {
            while neighbors.len() > 1 && state.tabu_list.contains(&neighbors[best_idx].mut_idx) {
                neighbors.remove(best_idx);
                best_idx = if neighbors.len() == 1 { 0 } else { deps.best_neighbor_idx(&neighbors)? };
            }
        }

        state.tabu_list.push_back(neighbors[best_idx].mut_idx);
        if state.tabu_list.len() > self.tabu_len {
            state.tabu_list.pop_front();
        }
        state.seq = neighbors[best_idx].seq.clone();

        Ok(neighbors[best_idx].score)
    }

    fn _update_state<T>(&self, deps: &T, state: &mut TabuState, train_score: f64, val_scorer: &dyn Scorer) where T: TabuOptDeps {
        let val_score = val_scorer.score(&state.seq);
        let iter = Iteration {
            train_score: train_score,
            val_score: val_score,
            best_seq: state.seq.clone()
        };
        deps.update_iters_state(state, &iter);
    }

    fn _run_tabu<T>(&self, deps: &T, stop_conds: &StopConds, actions_list: &[Action], train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> Result<ItersState, String> where T: TabuOptDeps {
        let mut state = deps.initial_state(self, actions_list)?;

        let initial_train_score = train_scorer.score(&state.seq);
        deps.update_state(self, &mut state, initial_train_score, val_scorer);

        while !deps.should_stop(stop_conds, &state.iters_state) {
            let train_score = deps.new_seq(self, &mut state, train_scorer)?;
            deps.update_state(self, &mut state, train_score, val_scorer);
        }

        Ok(state.iters_state)
    }

    fn run_tabu(&self, stop_conds: &StopConds, actions_list: &[Action], train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> Result<ItersState, String> {
        self._run_tabu(&TabuOptDepsImpl, stop_conds, actions_list, train_scorer, val_scorer)
    }
}
