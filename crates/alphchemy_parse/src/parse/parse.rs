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

    fn entry_for<'a>(&self, fields: &'a Fields, keys: &[&str]) -> Option<&'a Entry> {
        fields.entry_for(keys)
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
            if lines[next_idx].indent <= base_indent {
                break;
            }
            children.push(lines[next_idx].clone());
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
