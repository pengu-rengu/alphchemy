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

    fn entry_for<'a>(&self, fields: &Fields, keys: &[&'a str]) -> Option<Entry> {
        fields.entry_for(keys).cloned()
    }
}

struct FieldsDepsImpl;
impl FieldsDeps for FieldsDepsImpl {}

impl Fields {

    fn split_line(line: &Line) -> Result<(String, Option<String>), String> {
        match line.text.split_once(':') {
            Some(parts) => {
                let trimmed_part = parts.1.trim();
                let second_part = if trimmed_part.is_empty() { None } else { Some(trimmed_part.to_string()) };
                Ok((parts.0.trim().to_string(), second_part))
            }
            None => Err("Line is missing colon".to_string())
        }
    }

    fn iterate_child_lines(lines: &[Line], idx: usize, base_indent: usize) -> (usize, Vec<Line>) {
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

    pub fn from_lines(lines: &[Line]) -> Result<Fields, String> {
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

            let (key, inline) = Self::split_line(line)?;
            let (next_idx, child_lines) = Self::iterate_child_lines(lines, idx, base_indent);

            let entry = Entry { key, inline, child_lines };
            entries.push(entry);

            idx = next_idx;
        }

        Ok(Fields { entries })
    }

    fn entry_for(&self, keys: &[&str]) -> Option<&Entry> {
        for key in keys {
            for entry in &self.entries {
                if entry.key == *key {
                    return Some(entry);
                }
            }
        }
        None
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
        Some(text) => text.parse::<f64>().map_err(|_| number_error(keys, text))
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
mod tests {
    use super::*;
    use alphchemy_test_utils::{gen_text, gen_usize_between, gen_usize_with_max};
    use hegel::{TestCase, generators::{booleans, sampled_from}};

    #[hegel::composite]
    fn gen_line(tc: TestCase, indent: usize) -> Line {
        Line { indent, text: tc.draw(gen_text()) }
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
                    tc.assume(!text.is_empty() && !contains_newline && !is_comment);

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
            let result = Fields::split_line(&line);
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
            let result = Fields::iterate_child_lines(&lines, idx, base_indent);
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
}