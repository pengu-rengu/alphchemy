use serde_json::Value;

#[derive(Clone, Debug, PartialEq)]
enum PathSegment {
    Key(String),
    Aggregate {
        func: String,
        inner_segments: Vec<PathSegment>
    },
    SelfPath
}

fn is_aggregate_func(token: &str) -> bool {
    matches!(token, "len" | "mean" | "std" | "min" | "max")
}

fn parse_path(tokens: &[&str]) -> Result<Vec<PathSegment>, String> {
    let mut segments = Vec::new();
    let token_count = tokens.len();

    for (i, token) in tokens.iter().enumerate() {
        if is_aggregate_func(token) {
            let message = format!("Aggregate `{token}` must use colon syntax, e.g. `results.{token}:path.to.value`");
            return Err(message);
        }

        if *token == "self" {
            if i != token_count - 1 {
                return Err("`self` must be the final segment".to_string());
            }


            segments.push(PathSegment::SelfPath);
            continue;
        }

        let Some((func, first_inner_key)) = token.split_once(":") else {
            let key_segment = PathSegment::Key((*token).to_string());
            segments.push(key_segment);
            continue;
        };

        if !is_aggregate_func(func) {
            return Err(format!("Unknown aggregate `{func}`"));
        }
        if first_inner_key.is_empty() {
            return Err(format!("Aggregate `{func}` requires an inner path"));
        }

        let mut inner_tokens = vec![first_inner_key];
        inner_tokens.extend_from_slice(&tokens[i + 1..]);
        let inner_segments = parse_path(&inner_tokens)?;
        let aggregate = PathSegment::Aggregate {
            func: func.to_string(),
            inner_segments
        };
        segments.push(aggregate);

        return Ok(segments);
    }

    Ok(segments)
}

fn segment_path_text(segments: &[PathSegment]) -> String {
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
                text.push_str(&segment_path_text(inner_segments));
            }
        }
    }

    if text.is_empty() {
        return "<root>".to_string();
    }

    text
}

pub(crate) fn numeric_values(values: &[Value]) -> Vec<f64> {
    let mut numbers = Vec::new();

    for value in values {
        if let Some(flag) = value.as_bool() {
            numbers.push(if flag { 1.0 } else { 0.0 });
        } else if let Some(number) = value.as_f64() {
            numbers.push(number);
        }
    }

    numbers
}

pub(crate) fn apply_aggregate(func: &str, values: &[f64]) -> Result<f64, String> {
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
            if let Some(max) = maybe_max {
                Ok(*max)
            } else {
                Err("No elements for max aggregate".to_string())
            }
            //Ok(values.iter().copied().fold(f64::NEG_INFINITY, f64::max))
        },
        _ => Err(format!("Unrecognized aggregate: {func}"))
    }
}
/*
fn resolve_aggregate(array: &[Value], segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> {
    let mut values = Vec::new();

    for item in array {
        match resolve_segments(item, segments, full_path) {
            Ok(value) => values.push(value),
            Err(error) if error.starts_with("Missing ") => continue,
            Err(error) => return Err(error)
        }
    }

    Ok(values)
}
*/

fn resolve_aggregate(current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Vec<Value>, String> {
    if matches!(inner_segments.last(), Some(PathSegment::SelfPath)) {
        let target = resolve_segments(&current, &inner_segments[..inner_segments.len() - 1], full_path)?;
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
            match resolve_segments(item, inner_segments, full_path) {
                Ok(value) => values.push(value),
                Err(error) if error.starts_with("Missing ") => continue,
                Err(error) => return Err(error)
            }
        }

        Ok(values)
    }
}

fn resolve_aggregate_segment(current: &Value, func: &str, inner_segments: &[PathSegment], full_path: &str) -> Result<Value, String> {
    let values = resolve_aggregate(current, func, inner_segments, full_path)?;

    if func == "len" {
        return Ok(Value::from(values.len() as f64));
    }

    let numbers = numeric_values(&values);
    if numbers.is_empty() {
        let remaining_path = segment_path_text(inner_segments);
        if values.is_empty() {
            let message = format!("Missing aggregate values for {remaining_path} while resolving {full_path}");
            return Err(message);
        }

        let message = format!("Aggregate {func} found no numeric values for {remaining_path} while resolving {full_path}");
        return Err(message);
    }

    let aggregate = apply_aggregate(func, &numbers)?;
    return Ok(Value::from(aggregate));
}

fn resolve_key_segment(current: &Value, key: &str, prefix: &str, full_path: &str) -> Result<Value, String> {
    let Some(map) = current.as_object() else {
        let message = format!("Encountered a non-dictionary at {prefix} while resolving {full_path}");
        return Err(message);
    };
    let Some(value) = map.get(key) else {
        return Err("Missing key".to_string());
    };
    Ok((*value).clone())
}

fn resolve_segments(object: &Value, segments: &[PathSegment], full_path: &str) -> Result<Value, String> {
    let mut current = object.clone();

    for (i, segment) in segments.iter().enumerate() {
        let prefix = segment_path_text(&segments[..=i]);

        match segment {
            PathSegment::SelfPath => continue,
            PathSegment::Key(key) => current = resolve_key_segment(&current, key, &prefix, full_path)?,
            PathSegment::Aggregate { func, inner_segments } => return resolve_aggregate_segment(&current, func, inner_segments, full_path)
        }
    }

    Ok(current)
}

pub fn resolve_path(object: &Value, path: &str) -> Result<Value, String> {
    let tokens = path.split('.').collect::<Vec<_>>();
    let segments = parse_path(&tokens)?;
    let result = resolve_segments(object, &segments, path)?;

    if result.is_string() || result.is_boolean() || result.is_number() {
        return Ok(result);
    }

    Err("Resolved value must be a string, bool, or number".to_string())
}
