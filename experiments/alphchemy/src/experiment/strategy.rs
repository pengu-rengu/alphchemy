use std::collections::{HashMap, HashSet};

use serde::Deserialize;
use serde_json::Value;

use crate::network::network::{Network, NodePtr, Penalties};
use crate::network::logic_net::{LogicNet, LogicPenalties, parse_logic_net, parse_logic_penalties};
use crate::network::decision_net::{DecisionNet, DecisionPenalties, parse_decision_net, parse_decision_penalties};
use crate::features::features::{Feature, FeatTable};
use crate::features::features::{feat_ids, parse_feats};
use crate::actions::actions::Actions;
use crate::actions::logic_actions::{LogicActions, parse_logic_actions};
use crate::actions::decision_actions::{DecisionActions, parse_decision_actions};
use crate::optimizer::optimizer::StopConds;
use crate::optimizer::optimizer::parse_stop_conds;
use crate::optimizer::genetic::GeneticOpt;
use crate::optimizer::genetic::parse_opt;
use crate::utils::{get_field, from_field};

#[derive(Clone, Debug, Deserialize)]
pub struct EntrySchema {
    pub id: String,
    pub node_ptr: NodePtr,
    pub position_size: f64,
    pub max_positions: usize
}

#[derive(Clone, Debug, Deserialize)]
pub struct ExitSchema {
    pub id: String,
    pub node_ptr: NodePtr,
    pub entry_ids: Vec<String>,
    pub stop_loss: f64,
    pub take_profit: f64,
    pub max_hold_time: usize
}

#[derive(Clone, Debug)]
pub struct NetSignals {
    pub entries: HashMap<String, bool>,
    pub exits: HashMap<String, bool>
}

impl NetSignals {
    fn signal_value(signals: &HashMap<String, bool>, schema_id: &str, schema_type: &str) -> bool {
        let maybe_value = signals.get(schema_id);
        let value = maybe_value.unwrap_or_else(|| {
            panic!("missing {schema_type} signal for schema id: {schema_id}");
        });
        *value
    }

    pub fn entry_signal(&self, schema_id: &str) -> bool {
        Self::signal_value(&self.entries, schema_id, "entry")
    }

    pub fn exit_signal(&self, schema_id: &str) -> bool {
        Self::signal_value(&self.exits, schema_id, "exit")
    }
}

fn signal_map<T>(schemas: &[T], id_fn: impl Fn(&T) -> &str, value_fn: impl Fn(&T) -> bool) -> HashMap<String, bool> {
    let mut signals = HashMap::with_capacity(schemas.len());

    for schema in schemas {
        let schema_id = id_fn(schema);
        let value = value_fn(schema);
        let schema_id = schema_id.to_string();
        signals.insert(schema_id, value);
    }

    signals
}

fn false_signal_map<T>(schemas: &[T], id_fn: impl Fn(&T) -> &str) -> HashMap<String, bool> {
    signal_map(schemas, id_fn, |_| false)
}

pub struct Strategy<T: Network, P: Penalties<T>, A: Actions<T>> {
    pub base_net: T,
    pub feats: Vec<Box<dyn Feature>>,
    pub actions: A,
    pub penalties: P,
    pub stop_conds: StopConds,
    pub opt: GeneticOpt,
    pub global_max_positions: usize,
    pub entry_schemas: Vec<EntrySchema>,
    pub exit_schemas: Vec<ExitSchema>
}

pub fn net_signals<T: Network>(net: &mut T, entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema], feat_table: &FeatTable, start_idx: usize, end_idx: usize, delay: usize) -> Vec<NetSignals> {
    let n_rows = end_idx - start_idx + 1;
    let mut signals = Vec::with_capacity(n_rows);
    let default_entries = false_signal_map(entry_schemas, |entry_schema| entry_schema.id.as_str());
    let default_exits = false_signal_map(exit_schemas, |exit_schema| exit_schema.id.as_str());

    for _ in 0..delay {
        let default_signal = NetSignals {
            entries: default_entries.clone(),
            exits: default_exits.clone()
        };
        signals.push(default_signal);
    }

    net.reset_state();

    for i in delay..n_rows {
        let row_idx = start_idx + i - delay;
        net.eval(feat_table, row_idx);

        let entries = signal_map(
            entry_schemas,
            |entry_schema| entry_schema.id.as_str(),
            |entry_schema| net.node_value(&entry_schema.node_ptr)
        );

        let exits = signal_map(
            exit_schemas,
            |exit_schema| exit_schema.id.as_str(),
            |exit_schema| net.node_value(&exit_schema.node_ptr)
        );
        
        let new_signals = NetSignals { 
            entries, 
            exits 
        };
        signals.push(new_signals);
    }

    signals
}

fn validate_schema_id(ids: &mut HashSet<String>, schema_id: &str, field: &str, idx: usize, schema_type: &str) -> Result<(), String> {
    if schema_id.is_empty() {
        return Err(format!("{field}[{idx}]: id must not be empty"));
    }

    let schema_id_string = schema_id.to_string();
    if !ids.insert(schema_id_string) {
        return Err(format!("duplicate {schema_type} schema id: {schema_id}"));
    }

    Ok(())
}

fn parse_entry_schemas(json: &Value) -> Result<Vec<EntrySchema>, String> {
    let entry_schemas = from_field::<Vec<EntrySchema>>(json, "entry_schemas")?;
    let mut ids = HashSet::new();

    for (idx, entry_schema) in entry_schemas.iter().enumerate() {
        validate_schema_id(&mut ids, &entry_schema.id, "entry_schemas", idx, "entry")?;
    }

    Ok(entry_schemas)
}

fn parse_exit_schemas(json: &Value) -> Result<Vec<ExitSchema>, String> {
    let exit_schemas = from_field::<Vec<ExitSchema>>(json, "exit_schemas")?;
    let mut ids = HashSet::new();

    for (idx, exit_schema) in exit_schemas.iter().enumerate() {
        validate_schema_id(&mut ids, &exit_schema.id, "exit_schemas", idx, "exit")?;
    }

    Ok(exit_schemas)
}

fn validate_schemas(global_max_positions: usize, entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema]) -> Result<(), String> {
    if entry_schemas.is_empty() {
        return Err("entry_schemas must not be empty".to_string());
    }
    if exit_schemas.is_empty() {
        return Err("exit_schemas must not be empty".to_string());
    }
    if global_max_positions == 0 {
        return Err("global_max_positions must be > 0".to_string());
    }

    for (i, entry_schema) in entry_schemas.iter().enumerate() {
        let too_small = entry_schema.position_size <= 0.0;
        let too_large = entry_schema.position_size > 1.0;
        if too_small || too_large {
            return Err(format!("entry_schemas[{i}]: position_size must be > 0.0 and <= 1.0"));
        }
        if entry_schema.max_positions <= 0 {
            return Err(format!("entry_schemas[{i}]: max_positions must be > 0"));
        }
    }

    let mut entry_ids = HashSet::with_capacity(entry_schemas.len());
    for entry_schema in entry_schemas {
        let entry_id = entry_schema.id.as_str();
        entry_ids.insert(entry_id);
    }

    for (i, exit_schema) in exit_schemas.iter().enumerate() {
        if exit_schema.stop_loss <= 0.0 {
            return Err(format!("exit_schemas[{i}]: stop_loss must be > 0.0"));
        }
        if exit_schema.take_profit <= 0.0 {
            return Err(format!("exit_schemas[{i}]: take_profit must be > 0.0"));
        }
        if exit_schema.max_hold_time == 0 {
            return Err(format!("exit_schemas[{i}]: max_hold_time must be > 0"));
        }
        if exit_schema.entry_ids.is_empty() {
            return Err(format!("exit_schemas[{i}]: entry_ids must not be empty"));
        }

        for entry_id in &exit_schema.entry_ids {
            let entry_id_str = entry_id.as_str();
            let is_known = entry_ids.contains(entry_id_str);
            if !is_known {
                return Err(format!("exit_schemas[{i}]: unknown entry_id: {entry_id}"));
            }
        }
    }

    Ok(())
}

struct StrategyData {
    feats: Vec<Box<dyn Feature>>,
    feat_ids: Vec<String>,
    stop_conds: StopConds,
    opt: GeneticOpt,
    global_max_positions: usize,
    entry_schemas: Vec<EntrySchema>,
    exit_schemas: Vec<ExitSchema>
}

fn parse_strategy_data(json: &Value) -> Result<StrategyData, String> {
    let maybe_feats_json = json.get("feats");
    let maybe_feats_array = maybe_feats_json.and_then(|value| value.as_array());
    let feats_array = maybe_feats_array.ok_or_else(|| "missing or invalid feats array".to_string())?;

    let feats = parse_feats(feats_array)?;
    let feature_ids = feat_ids(&feats);
    let stop_conds_json = get_field(json, "stop_conds")?;
    let stop_conds = parse_stop_conds(stop_conds_json)?;
    let opt_json = get_field(json, "opt")?;
    let opt = parse_opt(opt_json)?;
    let global_max_positions = from_field::<usize>(json, "global_max_positions")?;
    let entry_schemas = parse_entry_schemas(json)?;
    let exit_schemas = parse_exit_schemas(json)?;
    validate_schemas(global_max_positions, &entry_schemas, &exit_schemas)?;

    Ok(StrategyData {
        feats,
        feat_ids: feature_ids,
        stop_conds,
        opt,
        global_max_positions,
        entry_schemas,
        exit_schemas
    })
}

pub fn parse_logic_strategy(json: &Value) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let strategy_data = parse_strategy_data(json)?;
    let base_net_json = get_field(json, "base_net")?;
    let base_net = parse_logic_net(base_net_json, &strategy_data.feat_ids)?;

    let actions_json = get_field(json, "actions")?;
    let actions = parse_logic_actions(actions_json, &strategy_data.feats)?;

    let penalties_json = get_field(json, "penalties")?;
    let penalties = parse_logic_penalties(penalties_json)?;
    Ok(Strategy {
        base_net,
        feats: strategy_data.feats,
        actions,
        penalties,
        stop_conds: strategy_data.stop_conds,
        opt: strategy_data.opt,
        global_max_positions: strategy_data.global_max_positions,
        entry_schemas: strategy_data.entry_schemas,
        exit_schemas: strategy_data.exit_schemas
    })
}

pub fn parse_decision_strategy(json: &Value) -> Result<Strategy<DecisionNet, DecisionPenalties, DecisionActions>, String> {
    let strategy_data = parse_strategy_data(json)?;
    let base_net_json = get_field(json, "base_net")?;
    let base_net = parse_decision_net(base_net_json, &strategy_data.feat_ids)?;

    let actions_json = get_field(json, "actions")?;
    let actions = parse_decision_actions(actions_json, &strategy_data.feats)?;

    let penalties_json = get_field(json, "penalties")?;
    let penalties = parse_decision_penalties(penalties_json)?;
    Ok(Strategy {
        base_net,
        feats: strategy_data.feats,
        actions,
        penalties,
        stop_conds: strategy_data.stop_conds,
        opt: strategy_data.opt,
        global_max_positions: strategy_data.global_max_positions,
        entry_schemas: strategy_data.entry_schemas,
        exit_schemas: strategy_data.exit_schemas
    })
}
