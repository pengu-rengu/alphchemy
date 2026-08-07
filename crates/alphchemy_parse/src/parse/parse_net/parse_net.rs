use std::collections::HashSet;

use alphchemy_engine::network::network::{NodePtr, Anchor};
use super::super::parse::{Fields, Entry, Line};
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

#[cfg_attr(test, automock)]
trait ParseNetDeps {
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

    fn fields_from_lines(&self, lines: &[Line]) -> Result<Fields, String> {
        Fields::from_lines(lines)
    }

    fn parse_node_fields(&self, entry: &Entry, slots: &Vec<Option<Fields>>) -> Result<(usize, Fields), String> {
        _parse_node_fields(&ParseNetDepsImpl, entry, slots)
    }
}

struct ParseNetDepsImpl;
impl ParseNetDeps for ParseNetDepsImpl {}

fn _parse_node_fields<T>(deps: &T, entry: &Entry, slots: &Vec<Option<Fields>>) -> Result<(usize, Fields), String> where T: ParseNetDeps {
    let idx = entry.key.parse::<usize>().map_err(|_| {
        format!("invalid node index: {}", entry.key)
    })?;

    let Some(slot) = slots.get(idx) else {
        return Err(format!("node index {idx} out of bounds"));
    };
    if slot.is_some() {
        return Err(format!("duplicate node index {idx}"));
    }

    Ok((idx, deps.fields_from_lines(&entry.child_lines)?))
}

fn _indexed_node_fields<T>(deps: &T, fields: Option<Fields>) -> Result<Vec<Fields>, String> where T: ParseNetDeps {
    let fields = match fields {
        Some(fields) => fields,
        None => Fields { entries: Vec::new() }
    };

    let count = fields.entries.len();
    if count > MAX_NODES { return Err(format!("Base network cannot have more than {MAX_NODES} nodes")) }

    let mut slots: Vec<Option<Fields>> = (0..count).map(|_| None).collect();

    for entry in &fields.entries {
        let (idx, node_fields) = deps.parse_node_fields(entry, &slots)?;
        slots[idx] = Some(node_fields);
    }

    slots.into_iter().map(|slot| slot.ok_or_else(|| {
        "node indices must be contiguous from 0".to_string()
    })).collect()
}

pub(super) fn indexed_node_fields(fields: Option<Fields>) -> Result<Vec<Fields>, String> {
    _indexed_node_fields(&ParseNetDepsImpl, fields)
}

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
    _parse_node_ptr(&ParseNetDepsImpl, fields)
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use crate::parse::parse::Entry;
    use alphchemy_test_utils::{gen_text, gen_usize_between, gen_usize_with_max};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

    #[hegel::composite]
    pub fn gen_fields(tc: TestCase) -> Fields {
        let n_entries = tc.draw(gen_usize_with_max(5));
        let mut entries = Vec::new();
        for _ in 0..n_entries {
            let key = tc.draw(gen_text());
            let inline = if tc.draw(booleans()) { Some(tc.draw(gen_text())) } else { None };
            let entry = Entry { key, inline, child_lines: Vec::new() };
            entries.push(entry);
        }
        Fields { entries }
    }

    #[hegel::composite]
    fn gen_entry(tc: TestCase, key: &str) -> Entry {
        let inline = if tc.draw(booleans()) { Some(tc.draw(gen_text())) } else { None };
        let n_lines = tc.draw(gen_usize_with_max(3));
        let mut child_lines = Vec::new();
        for _ in 0..n_lines {
            let line = Line {
                indent: tc.draw(gen_usize_with_max(4)),
                text: tc.draw(gen_text())
            };
            child_lines.push(line);
        }
        Entry { key: key.to_string(), inline, child_lines }
    }

    mod parse_node_fields_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum InvalidCase { Key, OutOfBounds, Duplicate, FieldsFromLines }

        #[derive(Debug)]
        struct TestContext {
            expected_idx: usize,
            expected_fields: Fields,
            result: Result<(usize, Fields), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let invalid_case = tc.draw(sampled_from(vec![InvalidCase::Key, InvalidCase::OutOfBounds, InvalidCase::Duplicate, InvalidCase::FieldsFromLines]));
            let invalid_oob = draw_invalid && invalid_case == InvalidCase::OutOfBounds;
            let invalid_dup = draw_invalid && invalid_case == InvalidCase::Duplicate;
            let invalid_from_lines = draw_invalid && invalid_case == InvalidCase::FieldsFromLines;

            let n_slots = if invalid_oob {
                tc.draw(gen_usize_with_max(10))
            } else {
                tc.draw(gen_usize_between(1, 10))
            };
            let idx = if invalid_oob {
                let offset = tc.draw(gen_usize_with_max(10));
                n_slots + offset
            } else {
                tc.draw(gen_usize_with_max(n_slots - 1))
            };

            let mut slots = Vec::new();
            for slot_idx in 0..n_slots {
                let filled = if slot_idx == idx { invalid_dup } else { tc.draw(booleans()) };
                if filled {
                    slots.push(Some(tc.draw(gen_fields())));
                } else {
                    slots.push(None);
                }
            }

            let key = if draw_invalid && invalid_case == InvalidCase::Key {
                format!("x{}", tc.draw(gen_text()))
            } else { idx.to_string() };
            let entry = tc.draw(gen_entry(&key));

            let expected_idx = idx;
            let expected_fields = tc.draw(gen_fields());

            let mut mock_deps = MockParseNetDeps::new();
            mock_deps.expect_fields_from_lines()
                .times(usize::from(!draw_invalid || invalid_from_lines))
                .withf({
                    let expected_lines = entry.child_lines.clone();
                    move |lines| *lines == expected_lines
                })
                .return_const(if invalid_from_lines { Err(String::new()) } else { Ok(expected_fields.clone()) });

            let result = _parse_node_fields(&mock_deps, &entry, &slots);
            TestContext { expected_idx, expected_fields, result }
        }

        #[hegel::test]
        fn test_parse_node_fields(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok((ctx.expected_idx, ctx.expected_fields)));
        }

        #[hegel::test]
        fn test_parse_node_fields_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }
}
