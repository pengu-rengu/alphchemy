use std::cmp::Ordering;
use rand::Rng;
use rand::seq::{IndexedRandom, SliceRandom};
use serde::Deserialize;
use serde_json::Value;
use crate::utils::parse_json;

use crate::actions::actions::Action;
use super::optimizer::{ItersState, POState, StopConds};

#[derive(Clone, Debug, Deserialize)]
pub struct GeneticOpt {
    pub pop_size: usize,
    pub seq_len: usize,
    pub n_elites: usize,
    pub mut_rate: f64,
    pub cross_rate: f64,
    #[serde(rename = "tournament_size")]
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
        for action in seq {
            if rng.random::<f64>() < self.mut_rate {
                *action = *actions_list.choose(&mut rng).unwrap();
            }
        }
    }

    pub fn select(&self, state: &POState) -> Vec<Action> {
        let mut rng = rand::rng();
        let mut indices = (0..self.pop_size).collect::<Vec<usize>>();
        indices.shuffle(&mut rng);
        let tournament = &indices[..self.tourn_size];

        let best_idx = *tournament
            .iter()
            .max_by(|&&a, &&b| state.scores[a].partial_cmp(&state.scores[b]).unwrap_or(Ordering::Equal))
            .unwrap_or(&0);

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
        indices.sort_by(|&a, &b| state.scores[b].partial_cmp(&state.scores[a]).unwrap_or(Ordering::Equal));

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

pub fn parse_opt(json: &Value) -> Result<GeneticOpt, String> {
    let opt_type = json.get("type").and_then(|v| v.as_str())
        .ok_or_else(|| "missing or invalid type field".to_string())?;

    if opt_type != "genetic" {
        return Err(format!("invalid optimizer type: {opt_type}"));
    }

    let opt = parse_json::<GeneticOpt>(json)?;

    if opt.pop_size == 0 {
        return Err("pop_size must be > 0".to_string());
    }

    if opt.seq_len == 0 {
        return Err("seq_len must be > 0".to_string());
    }
    if opt.n_elites > opt.pop_size {
        return Err("n_elites must be 0 - population size".to_string());
    }

    if !(0.0..=1.0).contains(&opt.mut_rate) {
        return Err("mut_rate must be 0.0 - 1.0".to_string()); 
    }
    if !(0.0..=1.0).contains(&opt.cross_rate) {
        return Err("cross_rate must be 0.0 - 1.0".to_string());
    }
    if opt.tourn_size == 0 || opt.tourn_size > opt.pop_size {
        return Err("tournament_size must be 1 - pop_size".to_string());
    }

    Ok(opt)
}
