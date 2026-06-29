// Shared block-field access for the experiment source format. This is the text
// analog of the serde_json field helpers in utils.rs: it splits one indentation
// level into named entries (preserving order), and every struct parser explicitly
// names the fields it wants. It is deliberately not a general AST/value parser.

#[derive(Clone, Copy)]
pub struct Line<'a> {
    pub indent: usize,
    pub text: &'a str
}

pub fn to_lines(source: &str) -> Vec<Line<'_>> {
    let mut lines = Vec::new();

    for line_str in source.lines() {
        let end_trimmed = line_str.trim_end();
        let content = end_trimmed.trim_start();
        if content.is_empty() {
            continue;
        }
        if content.starts_with('#') {
            continue;
        }

        let line = Line {
            indent: end_trimmed.len() - content.len(),
            text: content
        };
        lines.push(line);
    }

    lines
}

pub struct Entry<'a> {
    pub key: &'a str,
    pub inline: Option<&'a str>,
    pub children: Vec<Line<'a>>
}

pub struct Fields<'a> {
    pub entries: Vec<Entry<'a>>
}

impl<'a> Fields<'a> {
    pub fn from_lines(lines: &[Line<'a>]) -> Fields<'a> {
        let mut entries = Vec::new();
        if lines.is_empty() {
            return Fields { entries };
        }

        let base_indent = lines[0].indent;
        let mut idx = 0;

        while idx < lines.len() {
            let line = lines[idx];
            if line.indent != base_indent {
                idx += 1;
                continue;
            }

            let (key, inline) = match line.text.split_once(':') {
                Some(parts) => {
                    let trimmed_part = parts.1.trim();
                    match trimmed_part.is_empty() {
                        true => (parts.0.trim(), None),
                        false => (parts.0.trim(), Some(trimmed_part))
                    }
                }
                None => (line.text.trim(), None) // TODO: error if no ":"
            };

            let mut children = Vec::new();
            let mut next = idx + 1;
            while next < lines.len() {
                if lines[next].indent <= base_indent {
                    break;
                }
                children.push(lines[next]);
                next += 1;
            }

            let entry = Entry { key, inline, children };
            entries.push(entry);
            idx = next;
        }

        Fields { entries }
    }

    fn entry_for<'s>(&'s self, keys: &[&str]) -> Option<&'s Entry<'a>> {
        for key in keys {
            for entry in &self.entries {
                if entry.key == *key {
                    return Some(entry);
                }
            }
        }
        None
    }

    pub fn child_fields(&self, keys: &[&str]) -> Fields<'a> {
        match self.entry_for(keys) {
            Some(entry) => Fields::from_lines(&entry.children),
            None => Fields { entries: Vec::new() }
        }
    }

    pub fn string(&self, keys: &[&str], default: &str) -> String {
        let Some(entry) = self.entry_for(keys) else {
            return default.to_string();
        };
        match entry.inline {
            Some(text) => text.to_string(),
            None => default.to_string() // TODO: error if key without inline
        }
    }

    pub fn option_string(&self, keys: &[&str]) -> Option<String> {
        let Some(entry) = self.entry_for(keys) else {
            return None;
        };
        match entry.inline {
            None => None, // TODO: error if key without inline
            Some("null") => None,
            Some(text) => Some(text.to_string())
        }
    }

    pub fn f64(&self, keys: &[&str], default: f64) -> Result<f64, String> {
        let Some(entry) = self.entry_for(keys) else {
            return Ok(default);
        };
        match entry.inline {
            None => Ok(default), // TODO: error if key without inline
            Some(text) => text.parse::<f64>().map_err(|_| number_error(keys, text))
        }
    }

    pub fn option_f64(&self, keys: &[&str]) -> Result<Option<f64>, String> {
        let Some(entry) = self.entry_for(keys) else {
            return Ok(None);
        };
        match entry.inline {
            None => Ok(None), // TODO: error if key without inline
            Some("null") => Ok(None),
            Some(text) => {
                let value = text.parse::<f64>().map_err(|_| number_error(keys, text))?;
                Ok(Some(value))
            }
        }
    }

    pub fn usize(&self, keys: &[&str], default: usize) -> Result<usize, String> {
        let Some(entry) = self.entry_for(keys) else {
            return Ok(default);
        };
        match entry.inline {
            None => Ok(default), // TODO: error if key without inline
            Some(text) => text.parse::<usize>().map_err(|_| integer_error(keys, text))
        }
    }

    pub fn opt_usize(&self, keys: &[&str]) -> Result<Option<usize>, String> {
        let Some(entry) = self.entry_for(keys) else {
            return Ok(None);
        };
        match entry.inline {
            None => Ok(None), // TODO: error if key without inline
            Some("null") => Ok(None),
            Some(text) => {
                let value = text.parse::<usize>().map_err(|_| integer_error(keys, text))?;
                Ok(Some(value))
            }
        }
    }

    pub fn bool(&self, keys: &[&str], default: bool) -> Result<bool, String> {
        let Some(entry) = self.entry_for(keys) else {
            return Ok(default);
        };
        match entry.inline {
            None => Ok(default), // TODO: error if key without inline
            Some("true") => Ok(true),
            Some("false") => Ok(false),
            Some(text) => Err(format!("{} must be true or false, got \"{text}\"", keys[0]))
        }
    }

    pub fn string_list(&self, keys: &[&str]) -> Result<Vec<String>, String> {
        let Some(entry) = self.entry_for(keys) else {
            return Ok(Vec::new());
        };

        if !entry.children.is_empty() {
            return Err(list_error(keys));
        }

        let Some(inline) = entry.inline else {
            return Err(list_error(keys));
        };

        if inline == "[]" {
            return Err(format!("{} must omit the key instead of using []", keys[0]));
        }

        let parts = inline.split(',');
        let mut items = Vec::new();
        for part in parts {
            let item = part.trim().to_string();
            items.push(item);
        }
        Ok(items)
    }
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
