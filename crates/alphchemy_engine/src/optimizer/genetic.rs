use std::collections::HashMap;

use rand::distr::{Distribution, weighted::WeightedIndex};
use rand::Rng;
use rand::SeedableRng;
use rand::rngs::StdRng;
use rand::seq::SliceRandom;
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
    pub action_weights: HashMap<Action, f64>,
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

    fn random_action(&self, actions_list: &[Action], action_weights: &HashMap<Action, f64>, rng: &mut StdRng) -> Action {
        let mut weights = Vec::with_capacity(actions_list.len());

        for action in actions_list {
            let maybe_weight = action_weights.get(action);
            let weight = maybe_weight.copied().unwrap_or(1.0);
            weights.push(weight);
        }

        let distribution = WeightedIndex::new(weights).unwrap();
        actions_list[distribution.sample(rng)].clone()
    }

    fn shuffle(&self, indices: &mut [usize], rng: &mut StdRng) {
        indices.shuffle(rng);
    }

    fn best_idx(&self, tournament: &[usize], scores: &[f64]) -> Result<usize, String> {
        let maybe_best_idx = tournament.iter().max_by(|&idx_a, &idx_b| {
            scores[*idx_a].total_cmp(&scores[*idx_b])
        });

        maybe_best_idx.copied().ok_or_else(|| {
            format!("No best index found in tournament")
        })
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
                *action = deps.random_action(actions_list, &self.action_weights, &mut rng);
            }
        }

        POState { pop, scores: vec![0.0; self.pop_size], iters_state: ItersState::default(), rng }
    }

    fn _mutate<T>(&self, deps: &T, actions_list: &[Action], seq: &mut [Action], rng: &mut StdRng) where T: GeneticOptDeps {
        for action in seq {
            if deps.random_f64(rng) < self.mut_rate {
                *action = deps.random_action(actions_list, &self.action_weights, rng);
            }
        }
    }

    fn _select<T>(&self, deps: &T, state: &mut POState) -> Vec<Action> where T: GeneticOptDeps {
        let mut indices = (0..self.pop_size).collect::<Vec<usize>>();
        deps.shuffle(&mut indices, &mut state.rng);
        let tournament = &indices[..self.tourn_size];

        let best_idx = deps.best_idx(tournament, &state.scores).unwrap();
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

    fn _run_genetic<T>(&self, deps: &T, stop_conds: &StopConds, actions_list: &[Action], train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> ItersState where T: GeneticOptDeps {
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

    pub fn run_genetic(&self, stop_conds: &StopConds, actions_list: &[Action], train_scorer: &dyn Scorer, val_scorer: &dyn Scorer) -> ItersState {
        self._run_genetic(&GeneticOptDepsImpl, stop_conds, actions_list, train_scorer, val_scorer)
    }
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use crate::optimizer::optimizer::tests::{gen_action_seq, gen_actions_list, gen_po_state, gen_stop_conds};
    use alphchemy_test_utils::{FLOAT_MAX, gen_f64, gen_f64_with_min, gen_f64_with_max, gen_usize, gen_usize_between, gen_usize_with_max, gen_usize_with_min, gen_vec};
    use hegel::generators::{booleans, sampled_from};
    use hegel::TestCase;
    use mockall::predicate::{always, eq};
    use std::cell::Cell;
    use std::rc::Rc;

    #[hegel::composite]
    pub fn gen_genetic_opt(tc: TestCase, objectives: Option<&[Objective]>) -> GeneticOpt {
        let pop_size = tc.draw(gen_usize_between(1, 10));
        let seq_len = tc.draw(gen_usize_between(1, 10));
        let n_elites = tc.draw(gen_usize_with_max(pop_size));
        let tourn_size = tc.draw(gen_usize_between(1, pop_size));
        let mut_rate = tc.draw(gen_f64_with_max(1.0, false));
        let cross_rate = tc.draw(gen_f64_with_max(1.0, false));
        let opt_objectives = match objectives {
            Some(drawn) => drawn.to_vec(),
            None => Vec::new()
        };

        GeneticOpt { pop_size, seq_len, n_elites, mut_rate, cross_rate, tourn_size, objectives: opt_objectives, action_weights: HashMap::new(), random_seed: Some(tc.draw(gen_usize())) }
    }

    fn score_actions(seq: &[Action]) -> f64 {
        seq.len() as f64
    }

    #[hegel::test]
    fn test_initial_po_state(tc: TestCase) {
        let opt = tc.draw(gen_genetic_opt(None));

        let actions_len = tc.draw(gen_usize_with_min(1));
        let actions_list = tc.draw(gen_action_seq(actions_len, None));
        let action_idx = tc.draw(gen_usize_with_max(actions_len - 1));

        let expected_action = actions_list[action_idx].clone();

        let rng = StdRng::seed_from_u64(tc.draw(gen_usize()) as u64);

        let mut mock_deps = MockGeneticOptDeps::new();
        mock_deps.expect_create_rng()
            .times(1)
            .with(eq(opt.random_seed))
            .return_const(rng);

        let eq_actions_list = eq(actions_list.clone());
        let eq_action_weights = eq(opt.action_weights.clone());

        mock_deps.expect_random_action()
            .times(opt.pop_size * opt.seq_len)
            .with(eq_actions_list, eq_action_weights, always())
            .return_const(expected_action.clone());

        let state = opt._initial_po_state(&mock_deps, &actions_list);

        assert_eq!(state.pop, vec![vec![expected_action; opt.seq_len]; opt.pop_size]);
        assert_eq!(state.scores, vec![0.0; opt.pop_size]);
        assert_eq!(state.iters_state.iters, 0);
    }

    #[hegel::test]
    fn test_mutate(tc: TestCase) {
        let len = tc.draw(gen_usize_between(1, 10));
        let opt = tc.draw(gen_genetic_opt(None));
        tc.assume(opt.mut_rate != 0.0);
        tc.assume(opt.mut_rate != 1.0);

        let actions_list = tc.draw(gen_actions_list());
        let mut seq = tc.draw(gen_action_seq(len, Some(&actions_list)));
        let previous = seq.clone();
        let mutated_action = tc.draw(sampled_from(&actions_list));

        let should_mutate = Rc::new(tc.draw(gen_vec(booleans(), len)));
        let action_idx = Rc::new(Cell::new(0));

        let mutation_count = should_mutate.iter().map(|should_mutate_action| {
            usize::from(*should_mutate_action)
        }).sum::<usize>();

        let mut mock_deps = MockGeneticOptDeps::new();

        let should_mutate_clone = Rc::clone(&should_mutate);
        let action_idx_clone = Rc::clone(&action_idx);
        mock_deps.expect_random_f64()
            .times(len)
            .returning_st(move |_| {
                let idx = action_idx_clone.get();
                let should_mutate_action = if should_mutate_clone[idx] { 0.0 } else { 1.0 };
                action_idx_clone.set(idx + 1);
                should_mutate_action
            });

        let eq_action_weights = eq(opt.action_weights.clone());

        mock_deps.expect_random_action()
            .times(mutation_count)
            .with(eq(actions_list.clone()), eq_action_weights, always())
            .return_const(mutated_action.clone());

        let mut rng = StdRng::seed_from_u64(tc.draw(gen_usize()) as u64);
        opt._mutate(&mock_deps, &actions_list, &mut seq, &mut rng);

        for i in 0..len {
            let expected = if should_mutate[i] {
                mutated_action.clone()
            } else {
                previous[i].clone()
            };
            assert_eq!(seq[i], expected);
        }
    }

    mod best_idx_tests {
        use super::*;

        #[hegel::test]
        fn test_best_idx(tc: TestCase) {
            let pop_size = tc.draw(gen_usize_with_min(1));
            let tourn_size = tc.draw(gen_usize_between(1, pop_size));

            let idx_gen = gen_usize_with_max(pop_size - 1);
            let tournament = tc.draw(gen_vec(idx_gen, tourn_size));

            let best_tourn_idx = tc.draw(gen_usize_with_max(tourn_size - 1));
            let best_idx = tournament[best_tourn_idx];

            let mut scores = tc.draw(gen_vec(gen_f64(), pop_size));
            scores[best_idx] = tc.draw(gen_f64()) + 1.0 + FLOAT_MAX;

            let result = GeneticOptDepsImpl.best_idx(&tournament, &scores);
            assert_eq!(result, Ok(best_idx));
        }

        #[hegel::test]
        fn test_best_idx_empty(_tc: TestCase) {
            let result = GeneticOptDepsImpl.best_idx(&[], &[]);
            assert!(result.is_err());
        }
    }

    #[hegel::test]
    fn test_select(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        let pop_size = state.pop.len();
        let mut opt = tc.draw(gen_genetic_opt(None));
        opt.pop_size = pop_size;
        opt.tourn_size = tc.draw(gen_usize_between(1, pop_size));

        let best_idx = tc.draw(gen_usize_with_max(pop_size - 1));

        let idx_gen = gen_usize_with_max(pop_size - 1);
        let shuffled_indices = tc.draw(gen_vec(idx_gen, pop_size));
        let tournament = shuffled_indices[..opt.tourn_size].to_vec();

        let mut mock_deps = MockGeneticOptDeps::new();
        mock_deps.expect_shuffle().times(1).returning_st(move |indices, _| {
            indices.copy_from_slice(&shuffled_indices);
        });
        mock_deps.expect_best_idx().with(eq(tournament), eq(state.scores.clone())).times(1).return_const(Ok(best_idx));

        let result = opt._select(&mock_deps, &mut state);
        assert_eq!(result, state.pop[best_idx].clone());
    }

    mod crossover_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            parent1: Vec<Action>,
            parent2: Vec<Action>,
            split: usize,
            result: Vec<Action>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, do_cross: bool, parent1_first: bool) -> TestContext {
            let opt = tc.draw(gen_genetic_opt(None));
            let seq_len = opt.seq_len;
            let cross_rate = opt.cross_rate;
            tc.assume(cross_rate != 0.0);
            let split = tc.draw(gen_usize_between(1, seq_len - 1));

            let parent1 = tc.draw(gen_action_seq(seq_len, None));
            let parent2 = tc.draw(gen_action_seq(seq_len, None));

            let mut mock_deps = MockGeneticOptDeps::new();

            mock_deps.expect_random_split()
                .times(usize::from(do_cross))
                .return_const(split);

            mock_deps.expect_random_f64().times(1).return_const(tc.draw(if do_cross {
                gen_f64_with_max(cross_rate, true)
            } else {
                gen_f64_with_min(cross_rate)
            }));

            mock_deps.expect_random_bool().times(1).return_const(parent1_first);

            let mut rng = StdRng::seed_from_u64(tc.draw(gen_usize()) as u64);

            let result = opt._crossover(&mock_deps, &parent1, &parent2, &mut rng);

            TestContext { parent1, parent2, split, result }
        }

        #[hegel::test]
        fn test_crossover_cross_parent1(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, true));
            let result = ctx.result;
            assert_eq!(result[..ctx.split], ctx.parent1[..ctx.split]);
            assert_eq!(result[ctx.split..], ctx.parent2[ctx.split..]);
        }

        #[hegel::test]
        fn test_crossover_cross_parent2(tc: TestCase) {
            let ctx = tc.draw(gen_context(true, false));
            let result = ctx.result;
            assert_eq!(result[..ctx.split], ctx.parent2[..ctx.split]);
            assert_eq!(result[ctx.split..], ctx.parent1[ctx.split..]);
        }

        #[hegel::test]
        fn test_crossover_no_cross(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, true));
            assert_eq!(ctx.result, ctx.parent1);
        }

        #[hegel::test]
        fn test_crossover_no_cross_parent2(tc: TestCase) {
            let ctx = tc.draw(gen_context(false, false));
            assert_eq!(ctx.result, ctx.parent2);
        }
    }

    mod get_elites_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected: Vec<Vec<Action>>,
            result: Vec<Vec<Action>>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, has_elites: bool) -> TestContext {
            let mut state = tc.draw(gen_po_state());
            let pop_size = state.pop.len();
            let mut opt = tc.draw(gen_genetic_opt(None));
            opt.n_elites = if has_elites {
                tc.draw(gen_usize_between(1, pop_size))
            } else { 0 };

            state.scores.clear();
            for i in 0..pop_size {
                state.scores.push(i as f64);
            }

            let mut expected = Vec::with_capacity(opt.n_elites);
            for i in 0..opt.n_elites {
                let elite_idx = pop_size - 1 - i;
                expected.push(state.pop[elite_idx].clone());
            }

            let result = GeneticOptDepsImpl.get_elites(&opt, &state);

            TestContext { expected, result }
        }

        #[hegel::test]
        fn test_get_elites(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert_eq!(ctx.result, ctx.expected);
        }

        #[hegel::test]
        fn test_get_elites_none(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert!(ctx.result.is_empty());
        }
    }

    #[hegel::test]
    fn test_new_child(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        let opt = tc.draw(gen_genetic_opt(None));

        let parent1 = tc.draw(gen_action_seq(opt.seq_len, None));
        let parent2 = tc.draw(gen_action_seq(opt.seq_len, None));

        let crossed_child = tc.draw(gen_action_seq(opt.seq_len, None));
        let mutated_child = tc.draw(gen_action_seq(opt.seq_len, None));

        let actions_list = tc.draw(gen_actions_list());

        let mut mock_deps = MockGeneticOptDeps::new();

        mock_deps.expect_select()
            .times(1)
            .return_const(parent1);

        mock_deps.expect_select()
            .times(1)
            .return_const(parent2);

        mock_deps.expect_crossover()
            .times(1)
            .return_const(crossed_child);

        let mutated_child_clone = mutated_child.clone();
        mock_deps.expect_mutate().times(1).returning_st(move |_, _, child, _| {
            child.clone_from_slice(&mutated_child_clone);
        });

        let result = opt._new_child(&mock_deps, &mut state, &actions_list);
        assert_eq!(result, mutated_child);
    }

    #[hegel::test]
    fn test_new_pop(tc: TestCase) {
        let mut state = tc.draw(gen_po_state());
        let opt = tc.draw(gen_genetic_opt(None));
        let seq_len = opt.seq_len;

        let elite = tc.draw(gen_action_seq(seq_len, None));
        let child = tc.draw(gen_action_seq(seq_len, None));

        let elites = vec![elite.clone(); opt.n_elites];
        let child_count = opt.pop_size - opt.n_elites;
        let children = vec![child.clone(); child_count];
        let expected_new_pop = elites.clone().into_iter().chain(children.into_iter()).collect::<Vec<_>>();

        let actions_list = tc.draw(gen_actions_list());
        let mut mock_deps = MockGeneticOptDeps::new();

        mock_deps.expect_get_elites()
            .times(1)
            .return_const(elites);

        mock_deps.expect_new_child()
            .times(child_count)
            .return_const(child.clone());

        opt._new_pop(&mock_deps, &mut state, &actions_list);

        assert_eq!(state.pop, expected_new_pop);
    }

    mod run_genetic_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_iters: Option<usize>,
            result: ItersState
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, has_actions: bool) -> TestContext {
            let opt = tc.draw(gen_genetic_opt(None));
            let stop_conds = tc.draw(gen_stop_conds());
            let actions_list = if has_actions { tc.draw(gen_actions_list()) } else { Vec::new() };

            let mut mock_deps = MockGeneticOptDeps::new();

            let mut expected_iters = None;
            if has_actions {
                let update_count = tc.draw(gen_usize_between(1, 4));
                let initial_iters = tc.draw(gen_usize());
                let stop_iter = initial_iters + update_count;
                let mut state = tc.draw(gen_po_state());
                state.iters_state.iters = initial_iters;

                mock_deps.expect_initial_po_state()
                    .times(1)
                    .return_const(state);

                mock_deps.expect_update_state()
                    .times(update_count)
                    .returning(|state, _, _| {
                        state.iters_state.iters += 1;
                    });

                mock_deps.expect_should_stop()
                    .times(update_count)
                    .returning(move |_, iters_state| iters_state.iters >= stop_iter);

                mock_deps.expect_new_pop()
                    .times(update_count - 1)
                    .return_const(());

                expected_iters = Some(stop_iter);
            }

            let result = opt._run_genetic(&mock_deps, &stop_conds, &actions_list, &score_actions, &score_actions);

            TestContext { expected_iters, result }
        }

        #[hegel::test]
        fn test_run_genetic(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert_eq!(ctx.result.iters, ctx.expected_iters.unwrap());
        }

        #[hegel::test]
        fn test_run_genetic_no_actions(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result.iters, 0);
        }
    }
}
