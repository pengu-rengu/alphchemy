use crate::actions::actions::{Action, Actions, construct_net};
use crate::experiment::experiment::{Experiment, ExperimentVariant};
use crate::network::network::{Network, Penalties};

use super::net_to_ps::NetToPs;
use super::features_to_ps::{emit_feats, CUSTOM_EMA_HELPER};
use super::strategy_to_ps::emit_strategy;

const HEADER_NOTE: &str = "// Auto-generated from alphchemy experiment.\n// Note: TradingView applies SL/TP intra-bar; repo backtest uses bar close.";

fn header(title: &str, fold_idx: usize, start_balance: f64) -> Result<Vec<String>, String> {
    Ok(vec![
        "//@version=6".to_string(),
        HEADER_NOTE.to_string(),
        format!("// Fold index: {fold_idx}"),
        format!("strategy(\"{title}\", overlay=true, initial_capital={start_balance})")
    ])
}

fn build_pinescript<T, P, A>(experiment: &Experiment<T, P, A>, title: &str, fold_idx: usize, best_val_seq: &[Action]) -> Result<String, String>
where
    T: Network + Clone + NetToPs,
    P: Penalties<T>,
    A: Actions<T>
{
    let strategy = &experiment.strategy;
    let schema = &experiment.backtest_schema;
    let net = construct_net(&strategy.base_net, best_val_seq, &strategy.actions);
    let net_emit = net.emit(schema.delay)?;
    let feat_lines = emit_feats(&strategy.feats)?;
    let strategy_emit = emit_strategy(strategy, schema, &net)?;

    let mut sections: Vec<String> = Vec::new();
    sections.push(header(title, fold_idx, schema.start_balance)?.join("\n"));
    sections.push(format!("// === Helpers ===\n{}", CUSTOM_EMA_HELPER));
    if !strategy_emit.helpers.is_empty() {
        sections.push(format!("// === Strategy helpers ===\n{}", strategy_emit.helpers.join("\n\n")));
    }
    sections.push(format!("// === Features ===\n{}", feat_lines.join("\n")));
    sections.push(format!("// === Net declarations ===\n{}", net_emit.declarations.join("\n")));
    sections.push(format!("// === Net evaluation (per bar) ===\n{}", net_emit.per_bar.join("\n")));
    sections.push(format!("// === Signals ===\n{}", strategy_emit.signal_lines.join("\n")));
    sections.push(format!("// === Actions ===\n{}", strategy_emit.action_lines.join("\n")));

    Ok(sections.join("\n\n") + "\n")
}

pub fn experiment_to_pinescript(experiment: &ExperimentVariant, title: &str, fold_idx: usize, best_val_seq: &[Action]) -> Result<String, String> {
    match experiment {
        ExperimentVariant::Logic(exp) => build_pinescript(exp, title, fold_idx, best_val_seq),
        ExperimentVariant::Decision(exp) => build_pinescript(exp, title, fold_idx, best_val_seq)
    }
}
