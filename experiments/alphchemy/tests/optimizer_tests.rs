use alphchemy::optimizer::optimizer::{StopConds, ItersState, Improvement, Objective};
use alphchemy::optimizer::genetic::GeneticOpt;
use alphchemy::experiment::backtest::BacktestMetric;
use alphchemy::actions::actions::Action;
use rand::rngs::StdRng;
use rand::SeedableRng;

fn default_stop_conds() -> StopConds {
    StopConds {
        max_iters: 10,
        train_patience: 5,
        val_patience: 5
    }
}

#[test]
fn test_stop_conds_max_iters() {
    let conds = default_stop_conds();
    let state = ItersState {
        iters: 10,
        train_improvements: vec![Improvement { iter: 9, score: 1.0 }],
        val_improvements: vec![Improvement { iter: 9, score: 1.0 }],
        best_train_seq: Vec::new(),
        best_val_seq: Vec::new(),
        best_train_score: 1.0,
        best_val_score: 1.0
    };
    assert!(conds.should_stop(&state));
}

#[test]
fn test_stop_conds_within_bounds() {
    let conds = default_stop_conds();
    let state = ItersState {
        iters: 5,
        train_improvements: vec![Improvement { iter: 4, score: 1.0 }],
        val_improvements: vec![Improvement { iter: 4, score: 1.0 }],
        best_train_seq: Vec::new(),
        best_val_seq: Vec::new(),
        best_train_score: 1.0,
        best_val_score: 1.0
    };
    assert!(!conds.should_stop(&state));
}

#[test]
fn test_stop_conds_train_patience_exceeded() {
    let conds = default_stop_conds();
    let state = ItersState {
        iters: 8,
        train_improvements: vec![Improvement { iter: 1, score: 1.0 }],
        val_improvements: vec![Improvement { iter: 7, score: 1.0 }],
        best_train_seq: Vec::new(),
        best_val_seq: Vec::new(),
        best_train_score: 1.0,
        best_val_score: 1.0
    };
    assert!(conds.should_stop(&state));
}

#[test]
fn test_stop_conds_val_patience_exceeded() {
    let conds = default_stop_conds();
    let state = ItersState {
        iters: 8,
        train_improvements: vec![Improvement { iter: 7, score: 1.0 }],
        val_improvements: vec![Improvement { iter: 1, score: 1.0 }],
        best_train_seq: Vec::new(),
        best_val_seq: Vec::new(),
        best_train_score: 1.0,
        best_val_score: 1.0
    };
    assert!(conds.should_stop(&state));
}

#[test]
fn test_stop_conds_no_improvements_yet() {
    let conds = default_stop_conds();
    let state = ItersState::default();
    assert!(!conds.should_stop(&state));
}

#[test]
fn test_genetic_opt_initial_state() {
    let opt = GeneticOpt {
        pop_size: 10,
        seq_len: 5,
        n_elites: 2,
        mut_rate: 0.1,
        cross_rate: 0.5,
        tourn_size: 3,
        objectives: vec![Objective { metric: BacktestMetric::ExcessSharpe, weight: 1.0 }],
        random_seed: None
    };

    let actions_list = vec![Action::NextFeat, Action::NextThreshold, Action::SetFeat];
    let state = opt.initial_po_state(&actions_list);

    assert_eq!(state.pop.len(), 10);
    for seq in &state.pop {
        assert_eq!(seq.len(), 5);
    }
    assert_eq!(state.scores.len(), 10);
}

#[test]
fn test_genetic_opt_crossover_length() {
    let opt = GeneticOpt {
        pop_size: 10,
        seq_len: 8,
        n_elites: 1,
        mut_rate: 0.0,
        cross_rate: 1.0,
        tourn_size: 3,
        objectives: vec![Objective { metric: BacktestMetric::ExcessSharpe, weight: 1.0 }],
        random_seed: None
    };

    let parent1 = vec![Action::NextFeat; 8];
    let parent2 = vec![Action::NextThreshold; 8];
    let mut rng = StdRng::seed_from_u64(0);
    let child = opt.crossover(&parent1, &parent2, &mut rng);

    assert_eq!(child.len(), 8);
}

#[test]
fn test_genetic_opt_run_genetic() {
    let opt = GeneticOpt {
        pop_size: 20,
        seq_len: 5,
        n_elites: 2,
        mut_rate: 0.1,
        cross_rate: 0.7,
        tourn_size: 3,
        objectives: vec![Objective { metric: BacktestMetric::ExcessSharpe, weight: 1.0 }],
        random_seed: None
    };

    let stop_conds = StopConds {
        max_iters: 5,
        train_patience: 10,
        val_patience: 10
    };

    let actions_list = vec![Action::NextFeat, Action::NextThreshold, Action::SetFeat];

    let train_fn = |seq: &[Action]| seq.len() as f64;
    let val_fn = |seq: &[Action]| seq.len() as f64;

    let result = opt.run_genetic(&stop_conds, &actions_list, &train_fn, &val_fn);

    assert_eq!(result.iters, 5);
    assert!(!result.best_train_seq.is_empty());
    assert!(!result.best_val_seq.is_empty());
}

#[test]
fn test_genetic_opt_empty_actions() {
    let opt = GeneticOpt {
        pop_size: 10,
        seq_len: 5,
        n_elites: 1,
        mut_rate: 0.1,
        cross_rate: 0.7,
        tourn_size: 3,
        objectives: vec![Objective { metric: BacktestMetric::ExcessSharpe, weight: 1.0 }],
        random_seed: None
    };

    let stop_conds = StopConds {
        max_iters: 5,
        train_patience: 10,
        val_patience: 10
    };

    let actions_list: Vec<Action> = vec![];
    let train_fn = |_: &[Action]| 0.0;
    let val_fn = |_: &[Action]| 0.0;

    let result = opt.run_genetic(&stop_conds, &actions_list, &train_fn, &val_fn);
    assert_eq!(result.iters, 0);
}

fn count_next_feat(seq: &[Action]) -> f64 {
    let mut count = 0.0;
    for action in seq {
        if matches!(action, Action::NextFeat) {
            count += 1.0;
        }
    }
    count
}

#[test]
fn test_genetic_opt_seed_is_deterministic() {
    let opt = GeneticOpt {
        pop_size: 20,
        seq_len: 6,
        n_elites: 2,
        mut_rate: 0.2,
        cross_rate: 0.7,
        tourn_size: 3,
        objectives: vec![Objective { metric: BacktestMetric::ExcessSharpe, weight: 1.0 }],
        random_seed: Some(42)
    };

    let stop_conds = StopConds {
        max_iters: 8,
        train_patience: 10,
        val_patience: 10
    };

    let actions_list = vec![Action::NextFeat, Action::NextThreshold, Action::SetFeat];
    let train_fn = |seq: &[Action]| count_next_feat(seq);
    let val_fn = |seq: &[Action]| count_next_feat(seq);

    let first = opt.run_genetic(&stop_conds, &actions_list, &train_fn, &val_fn);
    let second = opt.run_genetic(&stop_conds, &actions_list, &train_fn, &val_fn);

    assert_eq!(first.best_train_seq, second.best_train_seq);
    assert_eq!(first.best_val_seq, second.best_val_seq);
}
