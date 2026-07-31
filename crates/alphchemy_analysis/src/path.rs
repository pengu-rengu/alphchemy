use serde_json::Value;

#[cfg(test)]
use mockall::automock;

#[derive(Clone, Debug, PartialEq)]
pub(crate) enum PathSegment {
    Key(String),
    Aggregate {
        func: String,
        inner_segments: Vec<PathSegment>
    },
    SelfPath
}

#[cfg_attr(test, automock)]
pub(crate) trait PathDeps {
    fn is_aggregate_func(&self, token: &str) -> bool {
        matches!(token, "len" | "mean" | "std" | "min" | "max")
    }

    fn parse_path<'a>(&self, tokens: &[&'a str]) -> Result<Vec<PathSegment>, String> {
        _parse_path(&PathDepsImpl, tokens)
    }

    fn parse_segment<'a>(&self, token: &'a str, remaining_tokens: &[&'a str]) -> Result<PathSegment, String> {
        _parse_segment(&PathDepsImpl, token, remaining_tokens)
    }

    fn parse_aggregate_segment<'a>(&self, func: &'a str, first_inner_key: &'a str, remaining_tokens: &[&'a str]) -> Result<PathSegment, String> {
        _parse_aggregate_segment(&PathDepsImpl, func, first_inner_key, remaining_tokens)
    }

    fn segment_path_text(&self, segments: &[PathSegment]) -> String {
        _segment_path_text(&PathDepsImpl, segments)
    }

    fn numeric_values(&self, values: &[Value]) -> Vec<f64> {
        let mut numbers = Vec::new();

        for value in values {
            if let Some(flag) = value.as_bool() {
                let num = f64::from(flag);
                numbers.push(num);
            } else if let Some(num) = value.as_f64() {
                numbers.push(num);
            }
        }

        numbers
    }

    fn apply_aggregate(&self, func: &str, values: &[f64]) -> Result<f64, String> {
        match func {
            "mean" => Ok(values.iter().sum::<f64>() / values.len() as f64),
            "std" => {
                let mean = values.iter().sum::<f64>() / values.len() as f64;
                let squared_total = values.iter().map(|value| (value - mean).powi(2)).sum::<f64>();
                Ok((squared_total / values.len() as f64).sqrt())
            }
            "min" => {
                let maybe_min = values.iter().min_by(|a, b| {
                    a.total_cmp(b)
                });
                if let Some(min) = maybe_min {
                    Ok(*min)
                } else {
                    Err("No elements for min aggregate".to_string())
                }

            },
            "max" => {
                let maybe_max = values.iter().max_by(|a, b| {
                    a.total_cmp(b)
                });
                if let Some(max) = maybe_max { Ok(*max) } else { Err("No elements for max aggregate".to_string()) }
            },
            _ => Err(format!("Unrecognized aggregate: {func}"))
        }
    }

    fn resolve_aggregate(&self, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> {
        _resolve_aggregate(&PathDepsImpl, current, func, inner_segments, full_path)
    }

    fn resolve_aggregate_segment(&self, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Value, String> {
        _resolve_aggregate_segment(&PathDepsImpl, current, func, inner_segments, full_path)
    }

    fn resolve_key_segment(&self, current: &Value, key: &str, prefix: &str, full_path: &str) -> Result<Value, String> {
        let Some(map) = current.as_object() else {
            let message = format!("Encountered a non-dictionary at {prefix} while resolving {full_path}");
            return Err(message);
        };
        let Some(value) = map.get(key) else {
            return Err("Missing key".to_string());
        };
        Ok((*value).clone())
    }

    fn resolve_segments(&self, object: &Value, segments: &[PathSegment], full_path: &str) -> Result<Value, String> {
        _resolve_segments(&PathDepsImpl, object, segments, full_path)
    }
}

pub(crate) struct PathDepsImpl;
impl PathDeps for PathDepsImpl {}

fn _parse_path<T>(deps: &T, tokens: &[&str]) -> Result<Vec<PathSegment>, String> where T: PathDeps {
    let mut segments = Vec::new();

    for (i, token) in tokens.iter().enumerate() {
        let remaining_tokens = &tokens[i + 1..];
        let segment = deps.parse_segment(token, remaining_tokens)?;
        let is_aggregate = matches!(&segment, PathSegment::Aggregate { .. });
        segments.push(segment);

        if is_aggregate {
            return Ok(segments);
        }
    }

    Ok(segments)
}

fn _parse_segment<T>(deps: &T, token: &str, remaining_tokens: &[&str]) -> Result<PathSegment, String> where T: PathDeps {
    if deps.is_aggregate_func(token) {
        let message = format!("Aggregate `{token}` must use colon syntax, e.g. `results.{token}:path.to.value`");
        return Err(message);
    }

    if token == "self" {
        if !remaining_tokens.is_empty() {
            return Err("`self` must be the final segment".to_string());
        }
        return Ok(PathSegment::SelfPath);
    }

    let Some((func, first_inner_key)) = token.split_once(":") else {
        return Ok(PathSegment::Key(token.to_string()));
    };

    deps.parse_aggregate_segment(func, first_inner_key, remaining_tokens)
}

fn _parse_aggregate_segment<T>(deps: &T, func: &str, first_inner_key: &str, remaining_tokens: &[&str]) -> Result<PathSegment, String> where T: PathDeps {
    if !deps.is_aggregate_func(func) {
        return Err(format!("Unknown aggregate `{func}`"));
    }
    if first_inner_key.is_empty() {
        return Err(format!("Aggregate `{func}` requires an inner path"));
    }

    let mut inner_tokens = vec![first_inner_key];
    inner_tokens.extend_from_slice(remaining_tokens);
    let inner_segments = deps.parse_path(&inner_tokens)?;

    Ok(PathSegment::Aggregate {
        func: func.to_string(),
        inner_segments
    })
}

fn _segment_path_text<T>(deps: &T, segments: &[PathSegment]) -> String where T: PathDeps {
    let mut text = String::new();

    for segment in segments {
        match segment {
            PathSegment::Key(key) => {
                if text.is_empty() || text.ends_with(":") {
                    text.push_str(key);
                } else {
                    text.push('.');
                    text.push_str(key);
                }
            }
            PathSegment::SelfPath => {
                if !text.is_empty() {
                    text.push('.');
                }
                text.push_str("self");
            }
            PathSegment::Aggregate { func, inner_segments } => {
                if !text.is_empty() {
                    text.push('.');
                }
                text.push_str(func);
                text.push(':');
                let inner_text = deps.segment_path_text(inner_segments);
                text.push_str(&inner_text);
            }
        }
    }

    if text.is_empty() {
        return "<root>".to_string();
    }

    text
}

fn _resolve_aggregate<T>(deps: &T, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> where T: PathDeps {
    if matches!(inner_segments.last(), Some(PathSegment::SelfPath)) {
        let target = deps.resolve_segments(current, &inner_segments[..inner_segments.len() - 1], full_path)?;
        let Some(array) = target.as_array() else {
            let message = format!("Aggregate `{func}` with .self requires a list target while resolving `{full_path}`");
            return Err(message);
        };
        Ok(array.clone())
    } else {
        let Some(array) = current.as_array() else {
            let message = format!("Aggregate `{func}` requires a list target while resolving `{full_path}`");
            return Err(message);
        };
        let mut values = Vec::new();

        for item in array {
            match deps.resolve_segments(item, inner_segments, full_path) {
                Ok(value) => values.push(value),
                Err(error) if error.starts_with("Missing ") => continue,
                Err(error) => return Err(error)
            }
        }

        Ok(values)
    }
}

fn _resolve_aggregate_segment<T>(deps: &T, current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Value, String> where T: PathDeps {
    let values = deps.resolve_aggregate(current, func, inner_segments, full_path)?;

    if func == "len" {
        return Ok(Value::from(values.len() as f64));
    }

    let numbers = deps.numeric_values(&values);
    if numbers.is_empty() {
        let remaining_path = deps.segment_path_text(inner_segments);
        if values.is_empty() {
            let message = format!("Missing aggregate values for {remaining_path} while resolving {full_path}");
            return Err(message);
        }

        let message = format!("Aggregate {func} found no numeric values for {remaining_path} while resolving {full_path}");
        return Err(message);
    }

    let aggregate = deps.apply_aggregate(func, &numbers)?;
    return Ok(Value::from(aggregate));
}

fn _resolve_segments<T>(deps: &T, object: &Value, segments: &[PathSegment], full_path: &str) -> Result<Value, String> where T: PathDeps {
    let mut current = object.clone();

    for (i, segment) in segments.iter().enumerate() {
        let prefix = deps.segment_path_text(&segments[..=i]);

        match segment {
            PathSegment::SelfPath => continue,
            PathSegment::Key(key) => current = deps.resolve_key_segment(&current, key, &prefix, full_path)?,
            PathSegment::Aggregate { func, inner_segments } => return deps.resolve_aggregate_segment(&current, func, inner_segments, full_path)
        }
    }

    Ok(current)
}

fn _resolve_path<T>(deps: &T, object: &Value, path: &str) -> Result<Value, String> where T: PathDeps {
    let tokens = path.split('.').collect::<Vec<_>>();
    let segments = deps.parse_path(&tokens)?;
    let result = deps.resolve_segments(object, &segments, path)?;

    if result.is_string() || result.is_boolean() || result.is_number() {
        return Ok(result);
    }

    Err("Resolved value must be a string, bool, or number".to_string())
}

pub fn resolve_path(object: &Value, path: &str) -> Result<Value, String> {
    _resolve_path(&PathDepsImpl, object, path)
}

mod tests {
    
}
