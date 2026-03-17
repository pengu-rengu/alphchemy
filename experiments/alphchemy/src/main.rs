mod network;
mod features;
mod actions;
mod optimizer;
mod experiment;

use std::collections::HashMap;
use ndarray::Array1;
use rand::Rng;

use network::network::*;
use network::logic_net::*;
use actions::actions::*;
use actions::logic_actions::*;
use optimizer::optimizer::*;
use optimizer::genetic::*;
use features::features::*;
use experiment::strategy::*;
use experiment::backtest::*;
use experiment::experiment::*;
use experiment::tojson::*;

fn generate_ohlc_data(n_bars: usize) -> (Vec<f64>, HashMap<String, Array1<f64>>) {
    let mut rng = rand::rng();
    let mut close = Vec::with_capacity(n_bars);
    let mut price = 100.0;

    for _ in 0..n_bars {
        price *= 1.0 + rng.random_range(-0.02..0.02);
        close.push(price);
    }

    let mut open = Vec::with_capacity(n_bars);
    let mut high = Vec::with_capacity(n_bars);
    let mut low = Vec::with_capacity(n_bars);

    for i in 0..n_bars {
        let c = close[i];
        let spread = c * 0.01;
        open.push(c + rng.random_range(-spread..spread));
        high.push(c + rng.random_range(0.0..spread * 2.0));
        low.push(c - rng.random_range(0.0..spread * 2.0));
    }

    let mut ohlc_data = HashMap::new();
    ohlc_data.insert("open".to_string(), Array1::from_vec(open));
    ohlc_data.insert("high".to_string(), Array1::from_vec(high));
    ohlc_data.insert("low".to_string(), Array1::from_vec(low));
    ohlc_data.insert("close".to_string(), Array1::from_vec(close.clone()));

    (close, ohlc_data)
}

fn main() {
    let (close_prices, ohlc_data) = generate_ohlc_data(500);

    let feats: Vec<Box<dyn Feature>> = vec![
        Box::new(Constant { id: "const_0.5".to_string(), constant: 0.5 }),
        Box::new(RawReturns { id: "close_returns".to_string(), log_returns: true, ohlc: OHLC::Close })
    ];

    let base_net = LogicNet {
        nodes: vec![
            LogicNode::Input(InputNode { threshold: Some(0.5), feat_idx: Some(0), value: false }),
            LogicNode::Input(InputNode { threshold: Some(0.0), feat_idx: Some(1), value: false }),
            LogicNode::Gate(GateNode { gate: Some(Gate::Or), in1_idx: Some(0), in2_idx: Some(1), value: false }),
            LogicNode::Gate(GateNode { gate: Some(Gate::And), in1_idx: Some(0), in2_idx: Some(1), value: false })
        ],
        default_value: false
    };

    let penalties = LogicPenalties {
        node: 0.01,
        input: 0.0,
        gate: 0.0,
        recurrence: 0.05,
        feedforward: 0.0,
        used_feat: 0.0,
        unused_feat: 0.1
    };

    let logic_actions = LogicActions {
        meta_actions: HashMap::new(),
        thresholds: vec![],
        n_thresholds: 1,
        allow_recurrence: false,
        allowed_gates: vec![Gate::And, Gate::Or, Gate::Xor]
    };

    let opt = GeneticOpt {
        pop_size: 20,
        seq_len: 30,
        n_elites: 2,
        mut_rate: 0.1,
        cross_rate: 0.7,
        tourn_size: 3
    };

    let stop_conds = StopConds {
        max_iters: 10,
        train_patience: 5,
        val_patience: 5
    };

    let entry_ptr = NodePtr { anchor: Anchor::FromStart, idx: 2 };
    let exit_ptr = NodePtr { anchor: Anchor::FromStart, idx: 3 };

    let strategy = Strategy {
        base_net,
        feats,
        actions: logic_actions,
        penalties,
        stop_conds,
        opt,
        entry_ptr,
        exit_ptr,
        stop_loss: 0.02,
        take_profit: 0.05,
        max_hold_time: 50
    };

    let backtest_schema = BacktestSchema {
        start_offset: 10,
        start_balance: 10000.0,
        alloc_size: 0.5,
        delay: 1
    };

    let exp = Experiment {
        val_size: 0.15,
        test_size: 0.15,
        cv_folds: 2,
        fold_size: 0.6,
        backtest_schema,
        strategy
    };

    println!("Running experiment...");
    let results = run_experiment(&exp, &close_prices, &ohlc_data);

    let json = experiment_results_json(&results);
    println!("{}", serde_json::to_string_pretty(&json).unwrap());
}
