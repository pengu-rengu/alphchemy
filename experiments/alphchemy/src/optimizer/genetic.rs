use rand::Rng;
use rand::SeedableRng;
use rand::rngs::StdRng;
use rand::seq::{IndexedRandom, SliceRandom};
use serde::Serialize;
use serde_json::Value;
use crate::utils::to_json_with_tag;
#[cfg(test)]
use mockall::automock;

use crate::actions::actions::Action;
use super::optimizer::{ItersState, Objective, POState, Scorer, StopConds};

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

#[cfg_attr(test, automock)]
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

    fn update_state(&self, state: &mut POState, train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) {
        state.update_state(train_scorer, val_scorer);
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

    fn _run_genetic<T>(&self, deps: &T, stop_conds: &StopConds, actions_list: &[Action], train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> ItersState
    where
        T: GeneticOptDeps
    {
        if actions_list.is_empty() {
            return ItersState::default();
        }

        let mut state = deps.initial_po_state(self, actions_list);

        deps.update_state(&mut state, train_scorer, val_scorer);

        while !deps.should_stop(stop_conds, &state.iters_state) {
            deps.new_pop(self, &mut state, actions_list);
            deps.update_state(&mut state, train_scorer, val_scorer);
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;
    use std::rc::Rc;
    use hegel::TestCase;
    use hegel::generators::booleans;
    use mockall::Sequence;
    use mockall::predicate::{always, eq};
    use crate::optimizer::optimizer::tests::{gen_action_seq, gen_po_state, gen_stop_conds};
    use crate::test_utils::{gen_f64, gen_usize, gen_usize_with_max, gen_vec};

    #[hegel::composite]
    fn gen_genetic_opt(tc: TestCase) -> GeneticOpt {
        let pop_size = tc.draw(gen_usize_with_max(4)) + 1;
        let seq_len = tc.draw(gen_usize_with_max(3)) + 2;
        let n_elites = tc.draw(gen_usize_with_max(pop_size));
        let tourn_size = tc.draw(gen_usize_with_max(pop_size - 1)) + 1;
        let mut_rate = tc.draw(gen_f64());
        let mut_rate = mut_rate / 100.0;
        let cross_rate = tc.draw(gen_f64());
        let cross_rate = cross_rate / 100.0;

        GeneticOpt {
            pop_size,
            seq_len,
            n_elites,
            mut_rate,
            cross_rate,
            tourn_size,
            objectives: Vec::new(),
            random_seed: Some(tc.draw(gen_usize()))
        }
    }

    fn score_actions(seq: &[Action]) -> f64 {
        let len = seq.len();
        len as f64
    }

    #[hegel::test]
    fn test_initial_po_state(tc: TestCase) {
        let opt = tc.draw(gen_genetic_opt());
        let actions_len = tc.draw(gen_usize_with_max(4)) + 1;
        let actions_list = tc.draw(gen_action_seq(actions_len));
        let expected_action = actions_list[0].clone();
        let expected_calls = opt.pop_size * opt.seq_len;
        let seed = tc.draw(gen_usize());
        let seed = seed as u64;
        let mut mock_deps = MockGeneticOptDeps::new();
        let create_rng_dep = mock_deps.expect_create_rng().times(1);
        let create_rng_dep = create_rng_dep.with(eq(opt.random_seed));
        let rng = StdRng::seed_from_u64(seed);
        create_rng_dep.return_const(rng);

        let random_action_dep = mock_deps.expect_random_action().times(expected_calls);
        let random_action_dep = random_action_dep.with(eq(actions_list.clone()), always());
        random_action_dep.return_const(expected_action.clone());

        let state = opt._initial_po_state(&mock_deps, &actions_list);

        assert_eq!(state.pop.len(), opt.pop_size);
        assert_eq!(state.scores, vec![0.0; opt.pop_size]);
        assert_eq!(state.iters_state.iters, 0);

        for seq in state.pop {
            assert_eq!(seq, vec![expected_action.clone(); opt.seq_len]);
        }
    }

    #[hegel::test]
    fn test_mutate(tc: TestCase) {
        let len = tc.draw(gen_usize_with_max(9)) + 1;
        let should_mutate = Rc::new(tc.draw(gen_vec(booleans(), len)));
        let mut mutation_count = 0;
        for should_mutate_action in should_mutate.iter() {
            if *should_mutate_action {
                mutation_count += 1;
            }
        }

        let mut opt = tc.draw(gen_genetic_opt());
        opt.mut_rate = 0.5;
        let actions_list = vec![Action::NextFeat, Action::SetFeat];
        let mut seq = vec![Action::NextFeat; len];
        let seed = tc.draw(gen_usize());
        let seed = seed as u64;
        let mut rng = StdRng::seed_from_u64(seed);
        let random_idx = Rc::new(Cell::new(0));
        let mut mock_deps = MockGeneticOptDeps::new();

        let should_mutate_return = Rc::clone(&should_mutate);
        let random_idx_return = Rc::clone(&random_idx);
        let random_f64_dep = mock_deps.expect_random_f64().times(len);
        random_f64_dep.returning_st(move |_| {
            let idx = random_idx_return.get();
            let value = if should_mutate_return[idx] { 0.0 } else { 1.0 };
            random_idx_return.set(idx + 1);
            value
        });

        let random_action_dep = mock_deps.expect_random_action().times(mutation_count);
        let random_action_dep = random_action_dep.with(eq(actions_list.clone()), always());
        random_action_dep.return_const(Action::SetFeat);

        opt._mutate(&mock_deps, &actions_list, &mut seq, &mut rng);

        for i in 0..len {
            let expected = if should_mutate[i] { Action::SetFeat } else { Action::NextFeat };
            assert_eq!(seq[i], expected);
        }
    }

    #[hegel::test]
    fn test_select(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        let pop_size = state.pop.len();
        let mut opt = tc.draw(gen_genetic_opt());
        opt.pop_size = pop_size;
        opt.tourn_size = tc.draw(gen_usize_with_max(pop_size - 1)) + 1;
        let mut shuffled_indices = (0..pop_size).collect::<Vec<usize>>();
        shuffled_indices.reverse();
        let best_idx = shuffled_indices[0];
        state.scores = vec![0.0; pop_size];
        state.scores[best_idx] = 1.0;
        let expected = state.pop[best_idx].clone();
        let shuffled_indices_return = shuffled_indices.clone();
        let mut mock_deps = MockGeneticOptDeps::new();
        let shuffle_dep = mock_deps.expect_shuffle().times(1);
        shuffle_dep.returning_st(move |indices, _| {
            indices.copy_from_slice(&shuffled_indices_return);
        });

        let selected = opt._select(&mock_deps, &mut state);

        assert_eq!(selected, expected);
    }

    #[hegel::test]
    fn test_crossover(tc: TestCase) {
        let len = tc.draw(gen_usize_with_max(8)) + 2;
        let split = tc.draw(gen_usize_with_max(len - 2)) + 1;
        let do_crossover = tc.draw(booleans());
        let first_parent_first = tc.draw(booleans());
        let parent1 = vec![Action::NextFeat; len];
        let parent2 = vec![Action::SetFeat; len];
        let mut opt = tc.draw(gen_genetic_opt());
        opt.seq_len = len;
        opt.cross_rate = if do_crossover { 1.0 } else { 0.0 };
        let seed = tc.draw(gen_usize());
        let seed = seed as u64;
        let mut rng = StdRng::seed_from_u64(seed);
        let mut mock_deps = MockGeneticOptDeps::new();
        let random_f64_dep = mock_deps.expect_random_f64().times(1);
        random_f64_dep.return_const(0.5);
        let random_bool_dep = mock_deps.expect_random_bool().times(1);
        random_bool_dep.return_const(first_parent_first);

        let split_times = usize::from(do_crossover);
        let random_split_dep = mock_deps.expect_random_split().times(split_times);
        random_split_dep.return_const(split);

        let child = opt._crossover(&mock_deps, &parent1, &parent2, &mut rng);

        let expected = if do_crossover && first_parent_first {
            [&parent1[..split], &parent2[split..]].concat()
        } else if do_crossover {
            [&parent2[..split], &parent1[split..]].concat()
        } else if first_parent_first {
            parent1
        } else {
            parent2
        };
        assert_eq!(child, expected);
    }

    #[hegel::test]
    fn test_get_elites(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        let pop_size = state.pop.len();
        let mut opt = tc.draw(gen_genetic_opt());
        opt.n_elites = tc.draw(gen_usize_with_max(pop_size));
        state.scores.clear();

        for i in 0..pop_size {
            state.scores.push(i as f64);
        }

        let mut expected = Vec::with_capacity(opt.n_elites);
        for i in 0..opt.n_elites {
            let elite_idx = pop_size - 1 - i;
            expected.push(state.pop[elite_idx].clone());
        }

        let elites = GeneticOptDepsImpl.get_elites(&opt, &state);

        assert_eq!(elites, expected);
    }

    #[hegel::test]
    fn test_new_child(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        let opt = tc.draw(gen_genetic_opt());
        let parent1 = tc.draw(gen_action_seq(opt.seq_len));
        let parent2 = tc.draw(gen_action_seq(opt.seq_len));
        let crossed_child = tc.draw(gen_action_seq(opt.seq_len));
        let mutated_child = tc.draw(gen_action_seq(opt.seq_len));
        let actions_list = vec![Action::NextFeat, Action::SetFeat];
        let mutated_child_return = mutated_child.clone();
        let mut mock_deps = MockGeneticOptDeps::new();
        let mut sequence = Sequence::new();

        let parent1_dep = mock_deps.expect_select().times(1);
        let parent1_dep = parent1_dep.in_sequence(&mut sequence);
        parent1_dep.return_const(parent1);

        let parent2_dep = mock_deps.expect_select().times(1);
        let parent2_dep = parent2_dep.in_sequence(&mut sequence);
        parent2_dep.return_const(parent2);

        let crossover_dep = mock_deps.expect_crossover().times(1);
        let crossover_dep = crossover_dep.in_sequence(&mut sequence);
        crossover_dep.return_const(crossed_child);

        let mutate_dep = mock_deps.expect_mutate().times(1);
        let mutate_dep = mutate_dep.in_sequence(&mut sequence);
        mutate_dep.returning_st(move |_, _, child, _| {
            child.clone_from_slice(&mutated_child_return);
        });

        let child = opt._new_child(&mock_deps, &mut state, &actions_list);

        assert_eq!(child, mutated_child);
    }

    #[hegel::test]
    fn test_new_pop(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        let mut opt = tc.draw(gen_genetic_opt());
        opt.pop_size = tc.draw(gen_usize_with_max(4)) + 1;
        opt.n_elites = tc.draw(gen_usize_with_max(opt.pop_size));
        let seq_len = tc.draw(gen_usize_with_max(4)) + 1;
        let elite = tc.draw(gen_action_seq(seq_len));
        let child = tc.draw(gen_action_seq(seq_len));
        let elites = vec![elite.clone(); opt.n_elites];
        let child_count = opt.pop_size - opt.n_elites;
        let actions_list = vec![Action::NextFeat, Action::SetFeat];
        let mut mock_deps = MockGeneticOptDeps::new();
        let get_elites_dep = mock_deps.expect_get_elites().times(1);
        get_elites_dep.return_const(elites);
        let new_child_dep = mock_deps.expect_new_child().times(child_count);
        new_child_dep.return_const(child.clone());

        opt._new_pop(&mock_deps, &mut state, &actions_list);

        assert_eq!(state.pop.len(), opt.pop_size);
        for i in 0..opt.n_elites {
            assert_eq!(state.pop[i], elite);
        }
        for i in opt.n_elites..opt.pop_size {
            assert_eq!(state.pop[i], child);
        }
    }

    #[hegel::test]
    fn test_run_genetic_empty_actions(tc: TestCase) {
        let opt = tc.draw(gen_genetic_opt());
        let stop_conds = tc.draw(gen_stop_conds());
        let mock_deps = MockGeneticOptDeps::new();

        let result = opt._run_genetic(&mock_deps, &stop_conds, &[], &score_actions, &score_actions);

        assert_eq!(result.iters, 0);
        assert!(result.train_improvements.is_empty());
        assert!(result.val_improvements.is_empty());
    }

    #[hegel::test]
    fn test_run_genetic(tc: TestCase) {
        let opt = tc.draw(gen_genetic_opt());
        let stop_conds = tc.draw(gen_stop_conds());
        let actions_list = vec![Action::NextFeat, Action::SetFeat];
        let state = tc.draw(gen_po_state());
        let initial_iters = tc.draw(gen_usize());
        let stop_iter = initial_iters + 3;
        let mut state = state;
        state.iters_state.iters = initial_iters;
        let mut mock_deps = MockGeneticOptDeps::new();
        let initial_state_dep = mock_deps.expect_initial_po_state().times(1);
        initial_state_dep.return_const(state);
        let update_state_dep = mock_deps.expect_update_state().times(3);
        update_state_dep.returning(|state, _, _| {
            state.iters_state.iters += 1;
        });
        let should_stop_dep = mock_deps.expect_should_stop().times(3);
        should_stop_dep.returning(move |_, iters_state| {
            iters_state.iters >= stop_iter
        });
        let new_pop_dep = mock_deps.expect_new_pop().times(2);
        new_pop_dep.return_const(());

        let result = opt._run_genetic(&mock_deps, &stop_conds, &actions_list, &score_actions, &score_actions);

        assert_eq!(result.iters, stop_iter);
    }
}
