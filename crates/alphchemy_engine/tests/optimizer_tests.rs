use alphchemy_engine::optimizer::optimizer::{StopConds, ItersState, Improvement, Objective};
use alphchemy_engine::optimizer::genetic::GeneticOpt;
use alphchemy_engine::experiment::backtest::BacktestMetric;
use alphchemy_engine::actions::actions::Action;

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
    assert_eq!(result.best_train_seq.len(), opt.seq_len);
    assert_eq!(result.best_val_seq.len(), opt.seq_len);
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
