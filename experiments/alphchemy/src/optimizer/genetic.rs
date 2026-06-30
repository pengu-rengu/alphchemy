use rand::Rng;
use rand::SeedableRng;
use rand::rngs::StdRng;
use rand::seq::{IndexedRandom, SliceRandom};
use serde::Serialize;
use serde_json::Value;
use crate::utils::{compare_f64, to_json_with_tag};

use crate::actions::actions::Action;
use super::optimizer::{ItersState, Objective, POState, StopConds};

#[derive(Clone, Debug, Serialize)]
pub struct GeneticOpt {
    pub pop_size: usize,
    pub seq_len: usize,
    pub n_elites: usize,
    pub mut_rate: f64,
    pub cross_rate: f64,
    pub tourn_size: usize,
    pub objectives: Vec<Objective>,
    pub random_seed: Option<usize>
}

impl GeneticOpt {
    pub fn to_json(&self) -> Value {
        to_json_with_tag(self, "type", "genetic")
    }

    pub fn initial_po_state(&self, actions_list: &[Action]) -> POState {
        let mut rng = match self.random_seed {
            Some(seed) => StdRng::seed_from_u64(seed as u64),
            None => StdRng::from_os_rng()
        };
        let mut pop = vec![vec![Action::NewBranch; self.seq_len]; self.pop_size];

        for i in 0..self.pop_size {
            for j in 0..self.seq_len {
                pop[i][j] = actions_list.choose(&mut rng).unwrap().clone();
            }
        }

        POState {
            pop,
            scores: vec![0.0; self.pop_size],
            iters_state: ItersState::default(),
            rng
        }
    }

    pub fn mutate(&self, actions_list: &[Action], seq: &mut [Action], rng: &mut StdRng) {
        for action in seq {
            if rng.random::<f64>() < self.mut_rate {
                *action = actions_list.choose(rng).unwrap().clone();
            }
        }
    }

    pub fn select(&self, state: &mut POState) -> Vec<Action> {
        let mut indices = (0..self.pop_size).collect::<Vec<usize>>();
        indices.shuffle(&mut state.rng);
        let tournament = &indices[..self.tourn_size];

        let compare = |&&idx_a: &&usize, &&idx_b: &&usize| compare_f64(state.scores[idx_a], state.scores[idx_b]);
        let maybe_best = tournament.iter().max_by(compare);
        let best_idx = *maybe_best.unwrap_or(&0);

        state.pop[best_idx].clone()
    }

    pub fn crossover(&self, parent1: &[Action], parent2: &[Action], rng: &mut StdRng) -> Vec<Action> {
        if rng.random::<f64>() < self.cross_rate {
            let split = rng.random_range(1..self.seq_len);
            if rng.random::<bool>() {
                [&parent1[..split], &parent2[split..]].concat()
            } else {
                [&parent2[..split], &parent1[split..]].concat()
            }
        } else if rng.random::<bool>() {
            parent1.to_vec()
        } else {
            parent2.to_vec()
        }
    }

    pub fn get_elites(&self, state: &POState) -> Vec<Vec<Action>> {
        if self.n_elites == 0 {
            return Vec::new();
        }

        let mut indices: Vec<usize> = (0..state.scores.len()).collect();
        let compare = |&idx_a: &usize, &idx_b: &usize| compare_f64(state.scores[idx_b], state.scores[idx_a]);
        indices.sort_by(compare);

        indices[..self.n_elites].iter().map(|&i| state.pop[i].clone()).collect()
    }

    pub fn new_child(&self, state: &mut POState, actions_list: &[Action]) -> Vec<Action> {
        let parent1 = self.select(state);
        let parent2 = self.select(state);
        let mut child = self.crossover(&parent1, &parent2, &mut state.rng);
        self.mutate(actions_list, &mut child, &mut state.rng);
        child
    }

    pub fn new_pop(&self, state: &mut POState, actions_list: &[Action]) {
        let mut pop = Vec::with_capacity(self.pop_size);

        let elites = self.get_elites(state);
        pop.extend(elites);

        for _ in 0..(self.pop_size - self.n_elites) {
            let child = self.new_child(state, actions_list);
            pop.push(child);
        }

        state.pop = pop;
    }

    pub fn run_genetic<F, G>(&self, stop_conds: &StopConds, actions_list: &[Action], train_fn: &F, val_fn: &G) -> ItersState
    where
        F: Fn(&[Action]) -> f64,
        G: Fn(&[Action]) -> f64
    {
        if actions_list.is_empty() {
            return ItersState::default();
        }

        let mut state = self.initial_po_state(actions_list);

        state.update_state(train_fn, val_fn);

        while !stop_conds.should_stop(&state.iters_state) {
            self.new_pop(&mut state, actions_list);
            state.update_state(train_fn, val_fn);
        }

        state.iters_state
    }
}
