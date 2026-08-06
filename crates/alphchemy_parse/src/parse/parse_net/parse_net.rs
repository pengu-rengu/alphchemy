use std::collections::HashSet;

use super::super::parse::Fields;

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

// Place each node at the index given by its map key ("0", "1", ...), so source
// order is irrelevant. A non-numeric key, an out-of-range index, a duplicate, or
// a gap (which leaves a slot unfilled) is an explicit error.
pub(super) fn indexed_nodes<T>(fields: Option<Fields>, parse_node: impl Fn(&Fields) -> Result<T, String>) -> Result<Vec<T>, String> {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let mut nodes = Vec::new();

    let count = fields.entries.len();

    if count > MAX_NODES { return Err(format!("Base network cannot have more than {MAX_NODES} nodes")) }

    let mut slots: Vec<Option<T>> = (0..count).map(|_| None).collect();

    for entry in &fields.entries {
        let idx = entry.key.parse::<usize>().map_err(|_| format!("invalid node index: {}", entry.key))?;

        if idx >= count {
            return Err(format!("node index {idx} out of range 0..{count}"));
        }
        if slots[idx].is_some() {
            return Err(format!("duplicate node index {idx}"));
        }

        let node_fields = Fields::from_lines(&entry.child_lines)?;
        slots[idx] = Some(parse_node(&node_fields)?);
    }

    for slot in slots {
        let node = slot.ok_or_else(|| "node indices must be contiguous from 0".to_string())?;
        nodes.push(node);
    }
    Ok(nodes)
}
