use std::collections::HashSet;

use alphchemy_engine::network::network::{NodePtr, Anchor};
use super::super::parse::{Fields, Entry};
#[cfg(test)]
use mockall::automock;

const MAX_NODES: usize = 25;

pub(super) fn feat_id_set(feat_ids: &[String]) -> HashSet<&str> {
    feat_ids.iter().map(|feat_id| feat_id.as_str()).collect()
}

pub(super) fn validate_idx(idx: Option<usize>, n_nodes: usize, field: &str) -> Result<(), String> {
    if let Some(value) = idx && value >= n_nodes {
        return Err(format!("{field} out of range"));
    }
    Ok(())
}

fn parse_node_fields(entry: &Entry, slots: &Vec<Option<Fields>>) -> Result<(usize, Fields), String> {
    let idx = entry.key.parse::<usize>().map_err(|_| {
        format!("invalid node index: {}", entry.key)
    })?;

    let Some(slot) = slots.get(idx) else {
        return Err(format!("node index {idx} out of bounds"));
    };
    if slot.is_some() {
        return Err(format!("duplicate node index {idx}"));
    }

    Ok((idx, Fields::from_lines(&entry.child_lines)?))
}

pub(super) fn indexed_nodes_fields(fields: Option<Fields>) -> Result<Vec<Fields>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let count = fields.entries.len();
    if count > MAX_NODES { return Err(format!("Base network cannot have more than {MAX_NODES} nodes")) }

    let mut slots: Vec<Option<Fields>> = (0..count).map(|_| None).collect();

    for entry in &fields.entries {
        let (idx, node_fields) = parse_node_fields(entry, &slots)?;
        slots[idx] = Some(node_fields);
    }

    slots.into_iter().map(|slot| slot.ok_or_else(|| {
        "node indices must be contiguous from 0".to_string()
    })).collect()
}

#[cfg_attr(test, automock)]
trait ParseNetDeps {
    fn option_usize<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Result<Option<usize>, String> {
        fields.option_usize(keys)
    }

    fn string<'a>(&self, fields: &Fields, keys: &[&'a str], default: &str) -> Result<String, String> {
        fields.string(keys, default)
    }

    fn usize<'a>(&self, fields: &Fields, keys: &[&'a str], default: usize) -> Result<usize, String> {
        fields.usize(keys, default)
    }

    fn parse_anchor(&self, text: &str) -> Result<Anchor, String> {
        match text {
            "from_start" => Ok(Anchor::FromStart),
            "from_end" => Ok(Anchor::FromEnd),
            _ => Err(format!("invalid anchor: {text}"))
        }
    }

    fn parse_node_ptr(&self, fields: Option<Fields>) -> Result<NodePtr, String> {
        _parse_node_ptr(&ParseNetDepsImpl, fields)
    }
}

struct ParseNetDepsImpl;
impl ParseNetDeps for ParseNetDepsImpl {}

fn _parse_node_ptr<T>(deps: &T, fields: Option<Fields>) -> Result<NodePtr, String> where T: ParseNetDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let anchor_text = deps.string(&fields, &["anchor"], "from_start")?;
    let anchor = deps.parse_anchor(&anchor_text)?;
    let offset = deps.usize(&fields, &["offset"], 0)?;

    Ok(NodePtr { anchor, offset })
}

pub fn parse_node_ptr(fields: Option<Fields>) -> Result<NodePtr, String> {
    ParseNetDepsImpl.parse_node_ptr(fields)
}
