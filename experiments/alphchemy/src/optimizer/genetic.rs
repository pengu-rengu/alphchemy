use rand::Rng;
use rand::SeedableRng;
use rand::rngs::StdRng;
use rand::seq::{IndexedRandom, SliceRandom};
use serde::Serialize;
use serde_json::Value;
use crate::utils::to_json_with_tag;

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

trait GeneticOptDeps {
    fn create_rng(&self, random_seed: Option<usize>) -> StdRng {
        match random_seed {
            Some(seed) => StdRng::seed_from_u64(seed as u64),
            None => StdRng::from_os_rng()
        }
    }

    fn random_f64(&self, rng: &mut StdRng) -> f64 {
        rng.random::<f64>()
    }

    fn random_bool(&self, rng: &mut StdRng) -> bool {
        rng.random::<bool>()
    }

    fn random_split(&self, rng: &mut StdRng, seq_len: usize) -> usize {
        rng.random_range(1..seq_len)
    }

    fn random_action(&self, actions_list: &[Action], rng: &mut StdRng) -> Action {
        let maybe_action = actions_list.choose(rng);
        let action = maybe_action.unwrap();
        action.clone()
    }

    fn shuffle(&self, indices: &mut [usize], rng: &mut StdRng) {
        indices.shuffle(rng);
    }

    fn initial_po_state(&self, opt: &GeneticOpt, actions_list: &[Action]) -> POState {
        opt._initial_po_state(&GeneticOptDepsImpl, actions_list)
    }

    fn select(&self, opt: &GeneticOpt, state: &mut POState) -> Vec<Action> {
        opt._select(&GeneticOptDepsImpl, state)
    }

    fn crossover(&self, opt: &GeneticOpt, parent1: &[Action], parent2: &[Action], rng: &mut StdRng) -> Vec<Action> {
        opt._crossover(&GeneticOptDepsImpl, parent1, parent2, rng)
    }

    fn mutate(&self, opt: &GeneticOpt, actions_list: &[Action], seq: &mut [Action], rng: &mut StdRng) {
        opt._mutate(&GeneticOptDepsImpl, actions_list, seq, rng);
    }

    fn get_elites(&self, opt: &GeneticOpt, state: &POState) -> Vec<Vec<Action>> {
        if opt.n_elites == 0 {
            return Vec::new();
        }

        let mut indices: Vec<usize> = (0..state.scores.len()).collect();
        indices.sort_by(|&idx_a: &usize, &idx_b: &usize| {
            state.scores[idx_b].total_cmp(&state.scores[idx_a])
        });

        indices[..opt.n_elites].iter().map(|&i| state.pop[i].clone()).collect()
    }

    fn new_child(&self, opt: &GeneticOpt, state: &mut POState, actions_list: &[Action]) -> Vec<Action> {
        opt._new_child(&GeneticOptDepsImpl, state, actions_list)
    }

    fn new_pop(&self, opt: &GeneticOpt, state: &mut POState, actions_list: &[Action]) {
        opt._new_pop(&GeneticOptDepsImpl, state, actions_list);
    }

    fn update_state<F, G>(&self, state: &mut POState, train_fn: &F, val_fn: &G)
    where
        F: Fn(&[Action]) -> f64,
        G: Fn(&[Action]) -> f64
    {
        state.update_state(train_fn, val_fn);
    }

    fn should_stop(&self, stop_conds: &StopConds, state: &ItersState) -> bool {
        stop_conds.should_stop(state)
    }
}

struct GeneticOptDepsImpl;
impl GeneticOptDeps for GeneticOptDepsImpl {}

impl GeneticOpt {
    pub fn to_json(&self) -> Value {
        to_json_with_tag(self, "type", "genetic")
    }

    fn _initial_po_state<T>(&self, deps: &T, actions_list: &[Action]) -> POState where T: GeneticOptDeps {
        let mut rng = deps.create_rng(self.random_seed);
        let mut pop = vec![vec![Action::NewBranch; self.seq_len]; self.pop_size];

        for seq in &mut pop {
            for action in seq {
                *action = deps.random_action(actions_list, &mut rng);
            }
        }

        POState {
            pop,
            scores: vec![0.0; self.pop_size],
            iters_state: ItersState::default(),
            rng
        }
    }

    fn _mutate<T>(&self, deps: &T, actions_list: &[Action], seq: &mut [Action], rng: &mut StdRng) where T: GeneticOptDeps {
        for action in seq {
            if deps.random_f64(rng) < self.mut_rate {
                *action = deps.random_action(actions_list, rng);
            }
        }
    }

    fn _select<T>(&self, deps: &T, state: &mut POState) -> Vec<Action> where T: GeneticOptDeps {
        let mut indices = (0..self.pop_size).collect::<Vec<usize>>();
        deps.shuffle(&mut indices, &mut state.rng);
        let tournament = &indices[..self.tourn_size];

        let compare = |&&idx_a: &&usize, &&idx_b: &&usize| state.scores[idx_a].total_cmp(&state.scores[idx_b]);
        let maybe_best = tournament.iter().max_by(compare);
        let best_idx = *maybe_best.unwrap_or(&0);

        state.pop[best_idx].clone()
    }

    fn _crossover<T>(&self, deps: &T, parent1: &[Action], parent2: &[Action], rng: &mut StdRng) -> Vec<Action> where T: GeneticOptDeps {
        if deps.random_f64(rng) < self.cross_rate {
            let split = deps.random_split(rng, self.seq_len);
            if deps.random_bool(rng) {
                [&parent1[..split], &parent2[split..]].concat()
            } else {
                [&parent2[..split], &parent1[split..]].concat()
            }
        } else if deps.random_bool(rng) {
            parent1.to_vec()
        } else {
            parent2.to_vec()
        }
    }

    fn _new_child<T>(&self, deps: &T, state: &mut POState, actions_list: &[Action]) -> Vec<Action> where T: GeneticOptDeps {
        let parent1 = deps.select(self, state);
        let parent2 = deps.select(self, state);
        let mut child = deps.crossover(self, &parent1, &parent2, &mut state.rng);
        deps.mutate(self, actions_list, &mut child, &mut state.rng);
        child
    }

    fn _new_pop<T>(&self, deps: &T, state: &mut POState, actions_list: &[Action]) where T: GeneticOptDeps {
        let mut pop = Vec::with_capacity(self.pop_size);

        let elites = deps.get_elites(self, state);
        pop.extend(elites);

        for _ in 0..(self.pop_size - self.n_elites) {
            let child = deps.new_child(self, state, actions_list);
            pop.push(child);
        }

        state.pop = pop;
    }

    fn _run_genetic<F, G, T>(&self, deps: &T, stop_conds: &StopConds, actions_list: &[Action], train_fn: &F, val_fn: &G) -> ItersState
    where
        F: Fn(&[Action]) -> f64,
        G: Fn(&[Action]) -> f64,
        T: GeneticOptDeps
    {
        if actions_list.is_empty() {
            return ItersState::default();
        }

        let mut state = deps.initial_po_state(self, actions_list);

        deps.update_state(&mut state, train_fn, val_fn);

        while !deps.should_stop(stop_conds, &state.iters_state) {
            deps.new_pop(self, &mut state, actions_list);
            deps.update_state(&mut state, train_fn, val_fn);
        }

        state.iters_state
    }

    pub fn run_genetic<F, G>(&self, stop_conds: &StopConds, actions_list: &[Action], train_fn: &F, val_fn: &G) -> ItersState
    where
        F: Fn(&[Action]) -> f64,
        G: Fn(&[Action]) -> f64
    {
        self._run_genetic(&GeneticOptDepsImpl, stop_conds, actions_list, train_fn, val_fn)
    }
}
