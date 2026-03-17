use rand::Rng;
use rand::seq::{IndexedRandom, SliceRandom};

use crate::actions::actions::Action;
use super::optimizer::{ItersState, POState, StopConds};

#[derive(Clone, Debug)]
pub struct GeneticOpt {
    pub pop_size: usize,
    pub seq_len: usize,
    pub n_elites: usize,
    pub mut_rate: f64,
    pub cross_rate: f64,
    pub tourn_size: usize
}

impl GeneticOpt {
    pub fn initial_po_state(&self, actions_list: &[Action]) -> POState {
        let mut rng = rand::rng();
        let pop = (0..self.pop_size)
            .map(|_| {
                (0..self.seq_len)
                    .map(|_| *actions_list.choose(&mut rng).unwrap())
                    .collect()
            })
            .collect();

        POState {
            pop,
            scores: vec![0.0; self.pop_size],
            iters_state: ItersState::default()
        }
    }

    pub fn mutate(&self, actions_list: &[Action], seq: &mut [Action]) {
        let mut rng = rand::rng();
        for gene in seq.iter_mut() {
            if rng.random::<f64>() < self.mut_rate {
                *gene = *actions_list.choose(&mut rng).unwrap();
            }
        }
    }

    pub fn select(&self, state: &POState) -> Vec<Action> {
        let mut rng = rand::rng();
        let mut indices: Vec<usize> = (0..self.pop_size).collect();
        indices.shuffle(&mut rng);
        let tournament = &indices[..self.tourn_size];

        let best_idx = *tournament
            .iter()
            .max_by(|&&a, &&b| state.scores[a].partial_cmp(&state.scores[b]).unwrap())
            .unwrap();

        state.pop[best_idx].clone()
    }

    pub fn crossover(&self, parent1: &[Action], parent2: &[Action]) -> Vec<Action> {
        let mut rng = rand::rng();

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
        indices.sort_by(|&a, &b| state.scores[b].partial_cmp(&state.scores[a]).unwrap());

        indices[..self.n_elites]
            .iter()
            .map(|&i| state.pop[i].clone())
            .collect()
    }

    pub fn new_child(&self, state: &POState, actions_list: &[Action]) -> Vec<Action> {
        let parent1 = self.select(state);
        let parent2 = self.select(state);
        let mut child = self.crossover(&parent1, &parent2);
        self.mutate(actions_list, &mut child);
        child
    }

    pub fn new_pop(&self, state: &mut POState, actions_list: &[Action]) {
        let mut pop = Vec::with_capacity(self.pop_size);

        let elites = self.get_elites(state);
        pop.extend(elites);

        for _ in 0..(self.pop_size - self.n_elites) {
            pop.push(self.new_child(state, actions_list));
        }

        state.pop = pop;
    }

    pub fn run_genetic<F, G>(
        &self,
        stop_conds: &StopConds,
        actions_list: &[Action],
        train_fn: &F,
        val_fn: &G
    ) -> ItersState
    where
        F: Fn(&[Action]) -> f64,
        G: Fn(&[Action]) -> f64
    {
        let mut state = self.initial_po_state(actions_list);

        state.update_state(train_fn, val_fn);

        while !stop_conds.should_stop(&state.iters_state) {
            self.new_pop(&mut state, actions_list);
            state.update_state(train_fn, val_fn);
        }

        state.iters_state
    }
}
