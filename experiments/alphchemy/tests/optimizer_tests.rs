use alphchemy::optimizer::optimizer::{StopConds, ItersState, Improvement};
use alphchemy::optimizer::genetic::GeneticOpt;
use alphchemy::actions::actions::Action;

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
        best_seq: Vec::new(),
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
        best_seq: Vec::new(),
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
        best_seq: Vec::new(),
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
        best_seq: Vec::new(),
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
        tourn_size: 3
    };

    let actions_list = vec![Action::NextFeat, Action::NextThreshold, Action::SetFeatIdx];
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
        tourn_size: 3
    };

    let parent1 = vec![Action::NextFeat; 8];
    let parent2 = vec![Action::NextThreshold; 8];
    let child = opt.crossover(&parent1, &parent2);

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
        tourn_size: 3
    };

    let stop_conds = StopConds {
        max_iters: 5,
        train_patience: 10,
        val_patience: 10
    };

    let actions_list = vec![Action::NextFeat, Action::NextThreshold, Action::SetFeatIdx];

    let train_fn = |seq: &[Action]| seq.len() as f64;
    let val_fn = |seq: &[Action]| seq.len() as f64;

    let result = opt.run_genetic(&stop_conds, &actions_list, &train_fn, &val_fn);

    assert_eq!(result.iters, 5);
    assert!(!result.best_seq.is_empty());
}

#[test]
fn test_genetic_opt_empty_actions() {
    let opt = GeneticOpt {
        pop_size: 10,
        seq_len: 5,
        n_elites: 1,
        mut_rate: 0.1,
        cross_rate: 0.7,
        tourn_size: 3
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
