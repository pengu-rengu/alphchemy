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
use crate::utils::{parse_json, validate_identifier, get_field, field_array};

#[derive(Clone, Debug, Deserialize)]
pub struct EntrySchema {
    pub id: String,
    pub node_ptr: NodePtr,
    pub qty: f64
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
    let field_context = format!("{field}[{idx}].id");
    validate_identifier(schema_id, &field_context)?;

    let schema_id_string = schema_id.to_string();
    if !ids.insert(schema_id_string) {
        return Err(format!("duplicate {schema_type} schema id: {schema_id}"));
    }

    Ok(())
}

fn validate_entry_schema_ids(entry_schemas: &[EntrySchema]) -> Result<(), String> {
    let mut ids = HashSet::new();

    for (idx, entry_schema) in entry_schemas.iter().enumerate() {
        validate_schema_id(&mut ids, &entry_schema.id, "entry_schemas", idx, "entry")?;
    }

    Ok(())
}

fn validate_exit_schema_ids(exit_schemas: &[ExitSchema]) -> Result<(), String> {
    let mut ids = HashSet::new();

    for (idx, exit_schema) in exit_schemas.iter().enumerate() {
        validate_schema_id(&mut ids, &exit_schema.id, "exit_schemas", idx, "exit")?;
    }

    Ok(())
}

fn validate_schemas(entry_schemas: &[EntrySchema], exit_schemas: &[ExitSchema]) -> Result<(), String> {
    if entry_schemas.is_empty() {
        return Err("entry_schemas must not be empty".to_string());
    }
    if exit_schemas.is_empty() {
        return Err("exit_schemas must not be empty".to_string());
    }

    for (i, entry_schema) in entry_schemas.iter().enumerate() {
        if entry_schema.qty <= 0.0 {
            return Err(format!("entry_schemas[{i}]: qty must be > 0.0"));
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

struct StrategyJson<'a> {
    base_net_json: &'a Value,
    feats_json: &'a Vec<Value>,
    actions_json: &'a Value,
    penalties_json: &'a Value,
    stop_conds_json: &'a Value,
    opt_json: &'a Value,
    entry_schemas_json: &'a Value,
    exit_schemas_json: &'a Value
}

struct StrategyData {
    feats: Vec<Box<dyn Feature>>,
    feat_ids: Vec<String>,
    stop_conds: StopConds,
    opt: GeneticOpt,
    entry_schemas: Vec<EntrySchema>,
    exit_schemas: Vec<ExitSchema>
}

fn parse_strategy_json<'a>(json: &'a Value) -> Result<StrategyJson<'a>, String> {
    let base_net_json = get_field(json, "base_net")?;
    let feats_json = field_array(json, "feats")?;
    let actions_json = get_field(json, "actions")?;
    let penalties_json = get_field(json, "penalties")?;
    let stop_conds_json = get_field(json, "stop_conds")?;
    let opt_json = get_field(json, "opt")?;
    let entry_schemas_json = get_field(json, "entry_schemas")?;
    let exit_schemas_json = get_field(json, "exit_schemas")?;

    Ok(StrategyJson {
        base_net_json,
        feats_json,
        actions_json,
        penalties_json,
        stop_conds_json,
        opt_json,
        entry_schemas_json,
        exit_schemas_json
    })
}

fn parse_strategy_data(strategy_json: &StrategyJson) -> Result<StrategyData, String> {
    let feats = parse_feats(strategy_json.feats_json)?;
    let feat_ids = feat_ids(&feats);
    let stop_conds = parse_stop_conds(strategy_json.stop_conds_json)?;
    let opt = parse_opt(strategy_json.opt_json)?;
    let entry_schemas = parse_json::<Vec<EntrySchema>>(strategy_json.entry_schemas_json)?;
    let exit_schemas = parse_json::<Vec<ExitSchema>>(strategy_json.exit_schemas_json)?;

    validate_entry_schema_ids(&entry_schemas)?;
    validate_exit_schema_ids(&exit_schemas)?;
    validate_schemas(&entry_schemas, &exit_schemas)?;

    Ok(StrategyData {
        feats,
        feat_ids,
        stop_conds,
        opt,
        entry_schemas,
        exit_schemas
    })
}

pub fn parse_logic_strategy(json: &Value) -> Result<Strategy<LogicNet, LogicPenalties, LogicActions>, String> {
    let strategy_json = parse_strategy_json(json)?;
    let strategy_data = parse_strategy_data(&strategy_json)?;

    let base_net = parse_logic_net(strategy_json.base_net_json, &strategy_data.feat_ids)?;
    let actions = parse_logic_actions(strategy_json.actions_json, &strategy_data.feats)?;
    let penalties = parse_logic_penalties(strategy_json.penalties_json)?;

    Ok(Strategy {
        base_net,
        feats: strategy_data.feats,
        actions,
        penalties,
        stop_conds: strategy_data.stop_conds,
        opt: strategy_data.opt,
        entry_schemas: strategy_data.entry_schemas,
        exit_schemas: strategy_data.exit_schemas
    })
}

pub fn parse_decision_strategy(json: &Value) -> Result<Strategy<DecisionNet, DecisionPenalties, DecisionActions>, String> {
    let strategy_json = parse_strategy_json(json)?;
    let strategy_data = parse_strategy_data(&strategy_json)?;

    let base_net = parse_decision_net(strategy_json.base_net_json, &strategy_data.feat_ids)?;
    let actions = parse_decision_actions(strategy_json.actions_json, &strategy_data.feats)?;
    let penalties = parse_decision_penalties(strategy_json.penalties_json)?;
    
    Ok(Strategy {
        base_net,
        feats: strategy_data.feats,
        actions,
        penalties,
        stop_conds: strategy_data.stop_conds,
        opt: strategy_data.opt,
        entry_schemas: strategy_data.entry_schemas,
        exit_schemas: strategy_data.exit_schemas
    })
}
