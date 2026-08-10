// Shared block-field access for the experiment source format. This is the text
// analog of the serde_json field helpers in utils.rs: it splits one indentation
// level into named entries (preserving order), and every struct parser explicitly
// names the fields it wants. It is deliberately not a general AST/value parser.

#[cfg(test)]
use mockall::automock;

#[derive(Clone, Debug, PartialEq)]
pub struct Line {
    pub indent: usize,
    pub text: String
}

pub fn to_lines(source: &str) -> Vec<Line> {
    let mut lines = Vec::new();

    for line_str in source.lines() {
        let end_trimmed = line_str.trim_end();
        let content = end_trimmed.trim_start();
        if content.is_empty() || content.starts_with('#') {
            continue;
        }

        let line = Line {
            indent: end_trimmed.len() - content.len(),
            text: content.to_string()
        };
        lines.push(line);
    }

    lines
}

#[derive(Clone, Debug, PartialEq)]
pub struct Entry {
    pub key: String,
    pub inline: Option<String>,
    pub child_lines: Vec<Line>
}

#[derive(Clone, Debug, PartialEq)]
pub struct Fields {
    pub entries: Vec<Entry>
}

#[cfg_attr(test, automock)]
trait FieldsDeps {
    fn from_lines(&self, lines: &[Line]) -> Result<Fields, String> {
        Fields::from_lines(lines)
    }

    fn split_line(&self, line: &Line) -> Result<(String, Option<String>), String> {
        match line.text.split_once(':') {
            Some(parts) => {
                let trimmed_part = parts.1.trim();
                let second_part = if trimmed_part.is_empty() { None } else { Some(trimmed_part.to_string()) };
                Ok((parts.0.trim().to_string(), second_part))
            }
            None => Err("Line is missing colon".to_string())
        }
    }

    fn iterate_child_lines(&self, lines: &[Line], idx: usize, base_indent: usize) -> (usize, Vec<Line>) {
        let mut children = Vec::new();
        let mut next_idx = idx + 1;

        while next_idx < lines.len() {
            let next_line = &lines[next_idx];
            if next_line.indent <= base_indent {
                break;
            }
            children.push(next_line.clone());
            next_idx += 1;
        }

        (next_idx, children)
    }

    fn entry_from_line(&self, lines: &[Line], idx: usize, base_indent: usize) -> Result<(Entry, usize), String> {
        _entry_from_line(&FieldsDepsImpl, lines, idx, base_indent)
    }

    fn entry_for<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Option<Entry> {
        for key in keys {
            for entry in &fields.entries {
                if entry.key == *key {
                    return Some(entry.clone());
                }
            }
        }
        None
    }

}

struct FieldsDepsImpl;
impl FieldsDeps for FieldsDepsImpl {}

impl Fields {
    pub fn from_lines(lines: &[Line]) -> Result<Fields, String> {
        _from_lines(&FieldsDepsImpl, lines)
    }

    pub fn child_fields(&self, keys: &[&str]) -> Result<Option<Fields>, String> {
        _child_fields(&FieldsDepsImpl, self, keys)
    }

    pub fn string(&self, keys: &[&str], default: &str) -> Result<String, String> {
        _string(&FieldsDepsImpl, self, keys, default)
    }

    pub fn option_string(&self, keys: &[&str]) -> Result<Option<String>, String> {
        _option_string(&FieldsDepsImpl, self, keys)
    }

    pub fn f64(&self, keys: &[&str], default: f64) -> Result<f64, String> {
        _f64(&FieldsDepsImpl, self, keys, default)
    }

    pub fn option_f64(&self, keys: &[&str]) -> Result<Option<f64>, String> {
        _option_f64(&FieldsDepsImpl, self, keys)
    }

    pub fn usize(&self, keys: &[&str], default: usize) -> Result<usize, String> {
        _usize(&FieldsDepsImpl, self, keys, default)
    }

    pub fn option_usize(&self, keys: &[&str]) -> Result<Option<usize>, String> {
        _option_usize(&FieldsDepsImpl, self, keys)
    }

    pub fn bool(&self, keys: &[&str], default: bool) -> Result<bool, String> {
        _bool(&FieldsDepsImpl, self, keys, default)
    }

    pub fn string_list(&self, keys: &[&str], default: Vec<String>) -> Result<Vec<String>, String> {
        _string_list(&FieldsDepsImpl, self, keys, default)
    }
}

fn _entry_from_line<T>(deps: &T, lines: &[Line], idx: usize, base_indent: usize) -> Result<(Entry, usize), String> where T: FieldsDeps {
    let (key, inline) = deps.split_line(&lines[idx])?;
    let (next_idx, child_lines) = deps.iterate_child_lines(lines, idx, base_indent);

    let entry = Entry { key, inline, child_lines };
    Ok((entry, next_idx))
}

fn _from_lines<T>(deps: &T, lines: &[Line]) -> Result<Fields, String> where T: FieldsDeps {
    let mut entries = Vec::new();
    if lines.is_empty() {
        return Ok(Fields { entries });
    }

    let base_indent = lines[0].indent;
    let mut idx = 0;

    while idx < lines.len() {
        let line = &lines[idx];
        if line.indent != base_indent {
            idx += 1;
            continue;
        }

        let (entry, next_idx) = deps.entry_from_line(lines, idx, base_indent)?;
        entries.push(entry);

        idx = next_idx;
    }

    Ok(Fields { entries })
}

fn _child_fields<T>(deps: &T, fields: &Fields, keys: &[&str]) -> Result<Option<Fields>, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(None);
    };

    if entry.inline.is_some() {
        return Err(block_error(keys));
    }

    let fields = deps.from_lines(&entry.child_lines)?;
    Ok(Some(fields))
}

fn _string<T>(deps: &T, fields: &Fields, keys: &[&str], default: &str) -> Result<String, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(default.to_string());
    };
    match entry.inline.as_deref() {
        Some(text) => Ok(text.to_string()),
        None => Err(inline_error(keys))
    }
}

fn _option_string<T>(deps: &T, fields: &Fields, keys: &[&str]) -> Result<Option<String>, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(None);
    };
    match entry.inline.as_deref() {
        None => Err(inline_error(keys)),
        Some("null") => Ok(None),
        Some(text) => Ok(Some(text.to_string()))
    }
}

fn _f64<T>(deps: &T, fields: &Fields, keys: &[&str], default: f64) -> Result<f64, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(default);
    };
    match entry.inline.as_deref() {
        None => Err(inline_error(keys)),
        Some(text) => text.parse::<f64>().map_err(|_| {
            number_error(keys, text)
        })
    }
}

fn _option_f64<T>(deps: &T, fields: &Fields, keys: &[&str]) -> Result<Option<f64>, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(None);
    };
    match entry.inline.as_deref() {
        None => Err(inline_error(keys)),
        Some("null") => Ok(None),
        Some(text) => Ok(Some(text.parse::<f64>().map_err(|_| number_error(keys, text))?))
    }
}

fn _usize<T>(deps: &T, fields: &Fields, keys: &[&str], default: usize) -> Result<usize, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(default);
    };
    match entry.inline.as_deref() {
        None => Err(inline_error(keys)),
        Some(text) => text.parse::<usize>().map_err(|_| {
            integer_error(keys, text)
        })
    }
}

fn _option_usize<T>(deps: &T, fields: &Fields, keys: &[&str]) -> Result<Option<usize>, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(None);
    };
    match entry.inline.as_deref() {
        None => Err(inline_error(keys)),
        Some("null") => Ok(None),
        Some(text) => {
            Ok(Some(text.parse::<usize>().map_err(|_| {
                integer_error(keys, text)
            })?))
        }
    }
}

fn _bool<T>(deps: &T, fields: &Fields, keys: &[&str], default: bool) -> Result<bool, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(default);
    };
    match entry.inline.as_deref() {
        None => Err(inline_error(keys)),
        Some("true") => Ok(true),
        Some("false") => Ok(false),
        Some(text) => Err(format!("{} must be true or false, got \"{text}\"", keys[0]))
    }
}

fn _string_list<T>(deps: &T, fields: &Fields, keys: &[&str], default: Vec<String>) -> Result<Vec<String>, String> where T: FieldsDeps {
    let Some(entry) = deps.entry_for(fields, keys) else {
        return Ok(default);
    };

    if !entry.child_lines.is_empty() {
        return Err(list_error(keys));
    }

    let Some(inline) = entry.inline.as_deref() else {
        return Err(list_error(keys));
    };

    Ok(inline.split(',').map(|part| part.trim().to_string()).collect())
}

fn inline_error(keys: &[&str]) -> String {
    format!("{} must have an inline value", keys[0])
}

fn number_error(keys: &[&str], text: &str) -> String {
    format!("{} must be a number, got \"{text}\"", keys[0])
}

fn integer_error(keys: &[&str], text: &str) -> String {
    format!("{} must be a non-negative integer, got \"{text}\"", keys[0])
}

fn list_error(keys: &[&str]) -> String {
    format!("{} must be an inline comma-separated list", keys[0])
}

fn block_error(keys: &[&str]) -> String {
    format!("{} must be a nested block", keys[0])
}

#[cfg(test)]
pub mod tests {
    use super::*;
    use alphchemy_test_utils::{gen_f64, gen_text, gen_usize, gen_usize_between, gen_usize_with_max, gen_vec};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

    #[hegel::composite]
    fn gen_line(tc: TestCase, indent: usize) -> Line {
        Line { indent, text: tc.draw(gen_text()) }
    }

    #[hegel::composite]
    fn gen_entry(tc: TestCase, draw_inline: Option<bool>, maybe_inline: Option<&str>) -> Entry {
        let key = tc.draw(gen_text());
        let inline = if draw_inline.unwrap_or_else(|| tc.draw(booleans())) { 
            let maybe_inlne_owned = maybe_inline.map(String::from);
            Some(maybe_inlne_owned.unwrap_or_else(|| tc.draw(gen_text()))) 
        } else { None };
        let n_lines = tc.draw(gen_usize_with_max(3));
        
        let mut child_lines = Vec::new();
        for _ in 0..n_lines {
            let indent = tc.draw(gen_usize_with_max(4));
            child_lines.push(tc.draw(gen_line(indent)));
        }
        Entry { key, inline: inline.map(|text| text.to_string()), child_lines }
    }

    #[hegel::composite]
    pub fn gen_fields(tc: TestCase) -> Fields {
        let n_entries = tc.draw(gen_usize_with_max(5));
        let mut entries = Vec::new();
        for _ in 0..n_entries {
            entries.push(tc.draw(gen_entry(None, None)));
        }
        Fields { entries }
    }

    #[derive(Clone, Copy, Debug, PartialEq)]
    enum RowKind { Content, Empty, Comment }

    #[hegel::test]
    fn test_to_lines(tc: TestCase) {
        let n_rows = tc.draw(gen_usize_with_max(5));
        let mut source_parts = Vec::new();
        let mut expected_lines = Vec::new();

        for _ in 0..n_rows {
            let kind = tc.draw(sampled_from(vec![RowKind::Content, RowKind::Empty, RowKind::Comment]));
            match kind {
                RowKind::Content => {
                    let indent = tc.draw(gen_usize_with_max(4));
                    let text = tc.draw(gen_text());

                    let contains_newline = text.contains('\n');
                    let is_comment = text.starts_with('#');
                    tc.assume(!text.trim().is_empty() && text == text.trim() && !contains_newline && !is_comment);

                    let trailing = if tc.draw(booleans()) { "  " } else { "" };
                    let content = format!("{}{}{}", " ".repeat(indent), text, trailing);
                    source_parts.push(content);
                    expected_lines.push(Line { indent, text });
                }
                RowKind::Empty => {
                    let n_spaces = tc.draw(gen_usize_with_max(5));
                    let empty_row = " ".repeat(n_spaces);
                    source_parts.push(empty_row);
                }
                RowKind::Comment => {
                    let indent = tc.draw(gen_usize_with_max(4));
                    let body = tc.draw(gen_text());
                    tc.assume(!body.contains('\n'));
                    source_parts.push(format!("{}#{}", " ".repeat(indent), body));
                }
            }
        }

        let source = source_parts.join("\n");
        let result = to_lines(&source);
        assert_eq!(result, expected_lines);
    }

    mod split_line_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Inline, NoInline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            expected_key: String,
            expected_inline: Option<String>,
            result: Result<(String, Option<String>), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let key = tc.draw(gen_text());
            let key_contains_colon = key.contains(':');
            tc.assume(!key_contains_colon);

            let (line_text, expected_key, expected_inline) = match case {
                Case::Inline => {
                    let value = tc.draw(gen_text());
                    tc.assume(!value.trim().is_empty());

                    let line_text = format!("{key}:{value}");
                    (line_text, key.trim().to_string(), Some(value.trim().to_string()))
                }
                Case::NoInline => {
                    let line_text = format!("{key}:");
                    (line_text, key.trim().to_string(), None)
                }
                Case::Invalid => (key, String::new(), None)
            };

            let indent = tc.draw(gen_usize_with_max(5));
            let line = Line { indent, text: line_text };
            let result = FieldsDepsImpl.split_line(&line);
            TestContext { expected_key, expected_inline, result }
        }

        #[hegel::test]
        fn test_split_line_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok((ctx.expected_key, ctx.expected_inline)));
        }

        #[hegel::test]
        fn test_split_line_no_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::NoInline));
            assert_eq!(ctx.result, Ok((ctx.expected_key, None)));
        }

        #[hegel::test]
        fn test_split_line_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod iterate_child_lines_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { NoChildren, ChildrenThenStop, ChildrenToEnd }

        #[derive(Debug)]
        struct TestContext {
            expected_next_idx: usize,
            expected_children: Vec<Line>,
            lines_len: usize,
            result: (usize, Vec<Line>)
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let base_indent = tc.draw(gen_usize_with_max(10));
            let n_prefix = tc.draw(gen_usize_with_max(10));

            let mut lines = Vec::new();
            for _ in 0..n_prefix {
                let indent = tc.draw(gen_usize_with_max(10));
                let prefix_line = tc.draw(gen_line(indent));
                lines.push(prefix_line);
            }
            let idx = lines.len();
            let base_line = tc.draw(gen_line(base_indent));
            lines.push(base_line);

            let stop_indent = tc.draw(gen_usize_with_max(base_indent));
            let stop_line = tc.draw(gen_line(stop_indent));

            let mut child_lines = Vec::new();
            let mut expected_children = Vec::new();

            for _ in 0..tc.draw(gen_usize_between(1, 10)) {
                let child_indent = base_indent + tc.draw(gen_usize_between(1, 10));
                let child = tc.draw(gen_line(child_indent));
                expected_children.push(child.clone());
                child_lines.push(child);
            }

            match case {
                Case::NoChildren => {
                    if tc.draw(booleans()) {
                        lines.push(stop_line);
                    }
                }
                Case::ChildrenThenStop => {
                    lines.extend(child_lines);
                    lines.push(stop_line);
                }
                Case::ChildrenToEnd => {
                    lines.extend(child_lines);
                }
            }

            let mut expected_next_idx = idx + 1;
            expected_next_idx += if case == Case::NoChildren { 0 } else { expected_children.len() };
            let result = FieldsDepsImpl.iterate_child_lines(&lines, idx, base_indent);
            TestContext { expected_next_idx, expected_children, lines_len: lines.len(), result }
        }

        #[hegel::test]
        fn test_iterate_child_lines_no_children(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::NoChildren));
            assert_eq!(ctx.result, (ctx.expected_next_idx, Vec::new()));
        }

        #[hegel::test]
        fn test_iterate_child_lines_then_stop(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::ChildrenThenStop));
            assert_eq!(ctx.result, (ctx.expected_next_idx, ctx.expected_children));
        }

        #[hegel::test]
        fn test_iterate_child_lines_to_end(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::ChildrenToEnd));
            assert_eq!(ctx.result, (ctx.lines_len, ctx.expected_children));
        }
    }

    mod entry_from_line_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_entry: Entry,
            expected_next_idx: usize,
            result: Result<(Entry, usize), String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_invalid: bool) -> TestContext {
            let base_indent = tc.draw(gen_usize_with_max(10));
            let mut lines = Vec::new();
            for _ in 0..tc.draw(gen_usize_between(1, 10)) {
                let indent = tc.draw(gen_usize_with_max(10));
                lines.push(tc.draw(gen_line(indent)));
            }
            let idx = tc.draw(gen_usize_between(0, lines.len() - 1));

            let expected_entry = tc.draw(gen_entry(None, None));

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_split_line()
                .times(1)
                .withf({
                    let expected_line = lines[idx].clone();
                    move |line| *line == expected_line
                })
                .return_const(if draw_invalid { Err(String::new()) } else { Ok((expected_entry.key.clone(), expected_entry.inline.clone())) });
            
            let expected_next_idx = tc.draw(gen_usize());
            mock_deps.expect_iterate_child_lines()
                .times(usize::from(!draw_invalid))
                .withf({
                    let expected_lines = lines.clone();
                    move |actual_lines, actual_idx, actual_base_indent| {
                        *actual_lines == expected_lines && *actual_idx == idx && *actual_base_indent == base_indent
                    }
                })
                .return_const((expected_next_idx, expected_entry.child_lines.clone()));

            let result = _entry_from_line(&mock_deps, &lines, idx, base_indent);
            TestContext { expected_entry, expected_next_idx, result }
        }

        #[hegel::test]
        fn test_entry_from_line(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, Ok((ctx.expected_entry, ctx.expected_next_idx)));
        }

        #[hegel::test]
        fn test_entry_from_line_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert!(ctx.result.is_err());
        }
    }

    mod from_lines_tests {
        use super::*;
        use std::cell::Cell;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Empty, Valid, Invalid }

        #[derive(Debug)]
        struct TestContext {
            expected_entries: Vec<Entry>,
            result: Result<Fields, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            if case == Case::Empty {
                let mock_deps = MockFieldsDeps::new();
                let result = _from_lines(&mock_deps, &[]);
                return TestContext { expected_entries: Vec::new(), result };
            }

            let base_indent = tc.draw(gen_usize_with_max(10));
            let n_entries = tc.draw(gen_usize_between(1, 10));
            let mut lines = Vec::new();
            let mut expected_entries = Vec::new();
            let mut expected_next_idxs = Vec::new();

            for _ in 0..n_entries {
                if !lines.is_empty() {
                    for _ in 0..tc.draw(gen_usize_with_max(10)) {
                        let skip_indent = base_indent + 1 + tc.draw(gen_usize_with_max(3));
                        let skip_line = tc.draw(gen_line(skip_indent));
                        lines.push(skip_line);
                    }
                }

                let idx = lines.len();
                lines.push(tc.draw(gen_line(base_indent)));

                let n_jumped = tc.draw(gen_usize_with_max(10));
                for _ in 0..n_jumped {
                    let jump_indent = tc.draw(gen_usize_with_max(10));
                    let jump_line = tc.draw(gen_line(jump_indent));
                    lines.push(jump_line);
                }

                expected_next_idxs.push(idx + 1 + n_jumped);
                expected_entries.push(tc.draw(gen_entry(None, None)));
            }

            let fail_at = if case == Case::Invalid {
                Some(tc.draw(gen_usize_with_max(n_entries - 1)))
            } else { None };

            let call_idx = Cell::new(0);
            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_from_line()
                .times(if let Some(i) = fail_at { i + 1 } else { n_entries })
                .withf({
                    let expected_lines = lines.clone();
                    move |actual_lines, _, actual_base_indent| *actual_lines == expected_lines && *actual_base_indent == base_indent
                })
                .returning({
                    let expected_entries = expected_entries.clone();
                    let expected_next_idxs = expected_next_idxs.clone();
                    move |_, _, _| {
                        let i = call_idx.get();
                        call_idx.set(i + 1);
                        if fail_at == Some(i) { Err(String::new()) } else {
                            Ok((expected_entries[i].clone(), expected_next_idxs[i]))
                        }
                    }
                });

            let result = _from_lines(&mock_deps, &lines);
            TestContext { expected_entries, result }
        }

        #[hegel::test]
        fn test_from_lines_empty(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Empty));
            assert_eq!(ctx.result, Ok(Fields { entries: Vec::new() }));
        }

        #[hegel::test]
        fn test_from_lines(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Valid));
            assert_eq!(ctx.result, Ok(Fields { entries: ctx.expected_entries }));
        }

        #[hegel::test]
        fn test_from_lines_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod entry_for_tests {
        use super::*;

        #[derive(Debug)]
        struct TestContext {
            expected_entry: Option<Entry>,
            result: Option<Entry>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, draw_missing: bool) -> TestContext {
            let n_entries = tc.draw(gen_usize_between(1, 5));
            let mut entries = Vec::new();
            for _ in 0..n_entries {
                entries.push(tc.draw(gen_entry(None, None)));
            }
            let fields = Fields { entries };

            let (keys_owned, expected_entry) = if draw_missing {
                let miss = tc.draw(gen_text());
                let doesnt_have_key = fields.entries.iter().all(|entry| entry.key != miss);
                tc.assume(doesnt_have_key);
                (vec![miss], None)
            } else {
                let match_key = fields.entries[tc.draw(gen_usize_with_max(n_entries - 1))].key.clone();
                let expected_entry = fields.entries.iter().find(|entry| entry.key == match_key).unwrap().clone();
                

                let n_keys = tc.draw(gen_usize_between(1, 10));
                let match_idx = tc.draw(gen_usize_with_max(n_keys - 1));
                let mut keys_owned = Vec::with_capacity(n_keys);

                for i in 0..n_keys {
                    if i == match_idx {
                        keys_owned.push(match_key.clone());
                    } else {
                        let miss = tc.draw(gen_text());
                        let doesnt_have_key = fields.entries.iter().all(|entry| entry.key != miss);
                        tc.assume(doesnt_have_key);
                        keys_owned.push(miss);
                    }
                }
                (keys_owned, Some(expected_entry))
            };

            let keys: Vec<&str> = keys_owned.iter().map(|key| key.as_str()).collect();
            let result = FieldsDepsImpl.entry_for(&fields, &keys);
            TestContext { expected_entry, result }
        }

        #[hegel::test]
        fn test_entry_for(tc: TestCase) {
            let ctx = tc.draw(gen_context(false));
            assert_eq!(ctx.result, ctx.expected_entry);
        }

        #[hegel::test]
        fn test_entry_for_missing(tc: TestCase) {
            let ctx = tc.draw(gen_context(true));
            assert_eq!(ctx.result, None);
        }
    }

    mod child_fields_tests {

        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Missing, Valid, Invalid }

        #[derive(Debug)]
        struct TestContext {
            expected_fields: Fields,
            result: Result<Option<Fields>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();

            let invalid_inline = case == Case::Invalid && tc.draw(booleans());
            let missing = case == Case::Missing;

            let entry = tc.draw(gen_entry(Some(invalid_inline), None));
            let expected_fields = tc.draw(gen_fields());

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        *actual_fields == expected_fields
                            && actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()))
                    }
                })
                .return_const(if missing { None } else { Some(entry.clone()) });

            mock_deps.expect_from_lines()
                .times(usize::from(!missing && !invalid_inline))
                .withf({
                    let expected_lines = entry.child_lines.clone();
                    move |actual_lines| *actual_lines == expected_lines
                })
                .return_const(if case == Case::Invalid && !invalid_inline { Err(String::new()) } else { Ok(expected_fields.clone()) });

            let result = _child_fields(&mock_deps, &fields, &keys);
            TestContext { expected_fields, result }
        }

        #[hegel::test]
        fn test_child_fields_missing(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Missing));
            assert_eq!(ctx.result, Ok(None));
        }

        #[hegel::test]
        fn test_child_fields(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Valid));
            assert_eq!(ctx.result, Ok(Some(ctx.expected_fields)));
        }

        #[hegel::test]
        fn test_child_fields_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod string_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Default, Inline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            default: String,
            expected_inline: String,
            result: Result<String, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();
            let default = tc.draw(gen_text());

            let missing = case == Case::Default;
            let entry = tc.draw(gen_entry(Some(case == Case::Inline), None));
            let expected_inline = entry.inline.clone().unwrap_or_default();

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        let eq_keys = actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()));
                        *actual_fields == expected_fields && eq_keys
                    }
                })
                .return_const(if missing { None } else { Some(entry) });

            let result = _string(&mock_deps, &fields, &keys, &default);
            TestContext { default, expected_inline, result }
        }

        #[hegel::test]
        fn test_string_default(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Default));
            assert_eq!(ctx.result, Ok(ctx.default));
        }

        #[hegel::test]
        fn test_string_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok(ctx.expected_inline));
        }

        #[hegel::test]
        fn test_string_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod option_string_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Null, Inline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            expected_inline: String,
            result: Result<Option<String>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();

            let (missing, has_inline, maybe_inline) = match case {
                Case::Null => if tc.draw(booleans()) {
                    (true, false, None)
                } else {
                    (false, true, Some("null"))
                },
                Case::Inline => (false, true, None),
                Case::Invalid => (false, false, None)
            };
            let entry = tc.draw(gen_entry(Some(has_inline), maybe_inline));
            if case == Case::Inline {
                let text = entry.inline.clone().unwrap_or_default();
                tc.assume(text != "null");
            }

            let expected_inline = entry.inline.clone().unwrap_or_default();

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        let eq_keys = actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()));
                        *actual_fields == expected_fields && eq_keys
                    }
                })
                .return_const(if missing { None } else { Some(entry) });

            let result = _option_string(&mock_deps, &fields, &keys);
            TestContext { expected_inline, result }
        }

        #[hegel::test]
        fn test_option_string_null(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Null));
            assert_eq!(ctx.result, Ok(None));
        }

        #[hegel::test]
        fn test_option_string_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok(Some(ctx.expected_inline)));
        }

        #[hegel::test]
        fn test_option_string_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod f64_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Default, Inline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            default: f64,
            expected_result: f64,
            result: Result<f64, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();
            let default = tc.draw(gen_f64());
            let expected_result = tc.draw(gen_f64());

            let expected_inline = expected_result.to_string();
            let (has_inline, maybe_inline) = match case {
                Case::Default => (false, None),
                Case::Inline => (true, Some(expected_inline.as_str())),
                Case::Invalid => (tc.draw(booleans()), None)
            };
            let entry = tc.draw(gen_entry(Some(has_inline), maybe_inline));
            if case == Case::Invalid && has_inline {
                tc.assume(entry.inline.clone().unwrap().parse::<f64>().is_err());
            }

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        let eq_keys = actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()));
                        *actual_fields == expected_fields && eq_keys
                    }
                })
                .return_const(if case == Case::Default { None } else { Some(entry) });

            let result = _f64(&mock_deps, &fields, &keys, default);
            TestContext { default, expected_result, result }
        }

        #[hegel::test]
        fn test_f64_default(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Default));
            assert_eq!(ctx.result, Ok(ctx.default));
        }

        #[hegel::test]
        fn test_f64_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok(ctx.expected_result));
        }

        #[hegel::test]
        fn test_f64_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod option_f64_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Null, Inline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            expected_result: f64,
            result: Result<Option<f64>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();
            let expected_result = tc.draw(gen_f64());
            let expected_inline = expected_result.to_string();

            let (missing, has_inline, maybe_inline) = match case {
                Case::Null => if tc.draw(booleans()) {
                    (true, false, None)
                } else {
                    (false, true, Some("null"))
                },
                Case::Inline => (false, true, Some(expected_inline.as_str())),
                Case::Invalid => (false, tc.draw(booleans()), None)
            };
            let entry = tc.draw(gen_entry(Some(has_inline), maybe_inline));
            if case == Case::Invalid && has_inline {
                let text = entry.inline.clone().unwrap();
                tc.assume(text != "null" && text.parse::<f64>().is_err());
            }

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        let eq_keys = actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()));
                        *actual_fields == expected_fields && eq_keys
                    }
                })
                .return_const(if missing { None } else { Some(entry) });

            let result = _option_f64(&mock_deps, &fields, &keys);
            TestContext { expected_result, result }
        }

        #[hegel::test]
        fn test_option_f64_null(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Null));
            assert_eq!(ctx.result, Ok(None));
        }

        #[hegel::test]
        fn test_option_f64_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok(Some(ctx.expected_result)));
        }

        #[hegel::test]
        fn test_option_f64_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod usize_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Default, Inline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            default: usize,
            expected_result: usize,
            result: Result<usize, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();
            let default = tc.draw(gen_usize());
            let expected_result = tc.draw(gen_usize());

            let expected_inline = expected_result.to_string();
            let (has_inline, maybe_inline) = match case {
                Case::Default => (false, None),
                Case::Inline => (true, Some(expected_inline.as_str())),
                Case::Invalid => (tc.draw(booleans()), None)
            };
            let entry = tc.draw(gen_entry(Some(has_inline), maybe_inline));
            if case == Case::Invalid && has_inline {
                tc.assume(entry.inline.clone().unwrap().parse::<usize>().is_err());
            }

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        let eq_keys = actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()));
                        *actual_fields == expected_fields && eq_keys
                    }
                })
                .return_const(if case == Case::Default { None } else { Some(entry) });

            let result = _usize(&mock_deps, &fields, &keys, default);
            TestContext { default, expected_result, result }
        }

        #[hegel::test]
        fn test_usize_default(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Default));
            assert_eq!(ctx.result, Ok(ctx.default));
        }

        #[hegel::test]
        fn test_usize_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok(ctx.expected_result));
        }

        #[hegel::test]
        fn test_usize_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod option_usize_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Null, Inline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            expected_result: usize,
            result: Result<Option<usize>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();
            let expected_result = tc.draw(gen_usize());
            let expected_inline = expected_result.to_string();

            let (missing, has_inline, maybe_inline) = match case {
                Case::Null => if tc.draw(booleans()) {
                    (true, false, None)
                } else {
                    (false, true, Some("null"))
                },
                Case::Inline => (false, true, Some(expected_inline.as_str())),
                Case::Invalid => (false, tc.draw(booleans()), None)
            };
            let entry = tc.draw(gen_entry(Some(has_inline), maybe_inline));
            if case == Case::Invalid && has_inline {
                let text = entry.inline.clone().unwrap();
                tc.assume(text != "null" && text.parse::<usize>().is_err());
            }

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        let eq_keys = actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()));
                        *actual_fields == expected_fields && eq_keys
                    }
                })
                .return_const(if missing { None } else { Some(entry) });

            let result = _option_usize(&mock_deps, &fields, &keys);
            TestContext { expected_result, result }
        }

        #[hegel::test]
        fn test_option_usize_null(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Null));
            assert_eq!(ctx.result, Ok(None));
        }

        #[hegel::test]
        fn test_option_usize_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok(Some(ctx.expected_result)));
        }

        #[hegel::test]
        fn test_option_usize_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod bool_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Default, Inline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            default: bool,
            expected_result: bool,
            result: Result<bool, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();
            let default = tc.draw(booleans());
            let expected_result = tc.draw(booleans());

            let (has_inline, maybe_inline) = match case {
                Case::Default => (false, None),
                Case::Inline => (true, Some(if expected_result { "true" } else { "false" })),
                Case::Invalid => (tc.draw(booleans()), None)
            };
            let entry = tc.draw(gen_entry(Some(has_inline), maybe_inline));
            if case == Case::Invalid && has_inline {
                let text = entry.inline.clone().unwrap();
                tc.assume(text != "true" && text != "false");
            }

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        let eq_keys = actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()));
                        *actual_fields == expected_fields && eq_keys
                    }
                })
                .return_const(if case == Case::Default { None } else { Some(entry) });

            let result = _bool(&mock_deps, &fields, &keys, default);
            TestContext { default, expected_result, result }
        }

        #[hegel::test]
        fn test_bool_default(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Default));
            assert_eq!(ctx.result, Ok(ctx.default));
        }

        #[hegel::test]
        fn test_bool_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok(ctx.expected_result));
        }

        #[hegel::test]
        fn test_bool_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }

    mod string_list_tests {
        use super::*;

        #[derive(Clone, Copy, Debug, PartialEq)]
        enum Case { Default, Inline, Invalid }

        #[derive(Debug)]
        struct TestContext {
            default: Vec<String>,
            expected_result: Vec<String>,
            result: Result<Vec<String>, String>
        }

        #[hegel::composite]
        fn gen_context(tc: TestCase, case: Case) -> TestContext {
            let fields = tc.draw(gen_fields());
            let n_keys = tc.draw(gen_usize_between(1, 10));
            let keys_owned = tc.draw(gen_vec(gen_text(), n_keys));
            let keys = keys_owned.iter().map(|key| key.as_str()).collect::<Vec<&str>>();

            let n_default = tc.draw(gen_usize_between(1, 10));
            let default = tc.draw(gen_vec(gen_text(), n_default));

            let n_parts = tc.draw(gen_usize_between(1, 10));
            let expected_result = tc.draw(gen_vec(gen_text(), n_parts));
            for part in &expected_result {
                tc.assume(!part.contains(',') && part == part.trim());
            }
            let expected_inline = expected_result.join(",");

            let (has_inline, maybe_inline, has_children) = match case {
                Case::Default => (None, None, false),
                Case::Inline => (Some(true), Some(expected_inline.as_str()), false),
                Case::Invalid => {
                    if tc.draw(booleans()) {
                        (Some(false), None, tc.draw(booleans()))
                    } else {
                        (None, None, true)
                    }
                }
            };
            let mut entry = tc.draw(gen_entry(has_inline, maybe_inline));
            if has_children {
                tc.assume(!entry.child_lines.is_empty());
            } else { entry.child_lines.clear(); }

            let mut mock_deps = MockFieldsDeps::new();
            mock_deps.expect_entry_for()
                .times(1)
                .withf({
                    let expected_fields = fields.clone();
                    let expected_keys = keys_owned.clone();
                    move |actual_fields, actual_keys| {
                        let eq_keys = actual_keys.iter().copied().eq(expected_keys.iter().map(|key| key.as_str()));
                        *actual_fields == expected_fields && eq_keys
                    }
                })
                .return_const(if case == Case::Default { None } else { Some(entry) });

            let result = _string_list(&mock_deps, &fields, &keys, default.clone());
            TestContext { default, expected_result, result }
        }

        #[hegel::test]
        fn test_string_list_default(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Default));
            assert_eq!(ctx.result, Ok(ctx.default));
        }

        #[hegel::test]
        fn test_string_list_inline(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Inline));
            assert_eq!(ctx.result, Ok(ctx.expected_result));
        }

        #[hegel::test]
        fn test_string_list_invalid(tc: TestCase) {
            let ctx = tc.draw(gen_context(Case::Invalid));
            assert!(ctx.result.is_err());
        }
    }
}