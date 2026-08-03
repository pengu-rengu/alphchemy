use alphchemy_utils::parse_timestamp;

use crate::filters::{Filter, FilterOperator, FilterValue};
use crate::query::{Query, Selection, SortSpec, Visibility};

fn parse_operator(operator: &str) -> Result<FilterOperator, String> {
    match operator {
        "==" => Ok(FilterOperator::Equal),
        ">=" => Ok(FilterOperator::GreaterEqual),
        ">" => Ok(FilterOperator::Greater),
        "<=" => Ok(FilterOperator::LessEqual),
        "<" => Ok(FilterOperator::Less),
        _ => Err(format!("Unknown operator: {operator}"))
    }
}

fn build_filter(path: String, operator_text: &str, value_text: &str) -> Result<Filter, String> {
    let operator = parse_operator(operator_text)?;
    let quoted = value_text.starts_with('"');
    let text = if quoted { value_text.trim_matches('"') } else { value_text };

    if let Ok(timestamp) = parse_timestamp(text) {
        return Ok(Filter {
            path,
            operator,
            value: FilterValue::Timestamp(timestamp)
        });
    }

    if quoted {
        if operator != FilterOperator::Equal {
            let message = format!("String filter only supports ==, got {operator_text}");
            return Err(message);
        }
        return Ok(Filter {
            path,
            operator,
            value: FilterValue::Text(text.to_string())
        });
    }

    if matches!(text, "true" | "false") {
        if operator != FilterOperator::Equal {
            let message = format!("Bool filter only supports ==, got {operator_text}");
            return Err(message);
        }
        return Ok(Filter {
            path,
            operator,
            value: FilterValue::Bool(text == "true")
        });
    }

    let number = text.parse::<f64>().map_err(|error| error.to_string())?;
    Ok(Filter {
        path,
        operator,
        value: FilterValue::Number(number)
    })
}

fn parse_filter(line: &str) -> Result<Filter, String> {
    let tokens = line.split_whitespace().collect::<Vec<_>>();
    if tokens.len() < 3 {
        return Err(format!("Invalid filter: {line}"));
    }
    let path = tokens[0].to_string();
    let operator = tokens[1];
    let value_text = tokens[2..].join(" ");
    build_filter(path, operator, &value_text)
}

fn split_wrapper(line: &str) -> Option<(&str, &str)> {
    let (prefix, path) = line.split_once('(')?;

    let path = path.strip_suffix(')')?;
    if path.is_empty() {
        return None;
    }
    Some((prefix, path))
}

fn parse_window(prefix: &str) -> Option<(usize, usize)> {
    let parts = prefix.split_once('+');
    let (limit_text, offset_text) = match parts {
        Some((limit_text, offset_text)) => (limit_text, Some(offset_text)),
        None => (prefix, None)
    };
    let limit = limit_text.parse::<usize>().ok()?;
    let offset = match offset_text {
        Some(offset_text) => offset_text.parse::<usize>().ok()?,
        None => 0
    };
    Some((limit, offset))
}

fn parse_selection(line: &str) -> Result<Selection, String> {
    if line == "count" {
        return Ok(Selection {
            text: line.to_string(),
            path: String::new(),
            aggregate: Some(line.to_string()),
            limit: None,
            offset: 0
        });
    }

    if let Some((prefix, path)) = split_wrapper(line) {
        if matches!(prefix, "mean" | "max" | "min" | "std") {
            return Ok(Selection {
                text: line.to_string(),
                path: path.to_string(),
                aggregate: Some(prefix.to_string()),
                limit: None,
                offset: 0
            });
        }

        if let Some((limit, offset)) = parse_window(prefix) {
            if !(1..=25).contains(&limit) {
                let message = format!("limit must be between 1 and 25, got {limit}");
                return Err(message);
            }
            if offset > 10000 {
                let message = format!("offset must be at most 10000, got {offset}");
                return Err(message);
            }
            return Ok(Selection {
                text: line.to_string(),
                path: path.to_string(),
                aggregate: None,
                limit: Some(limit),
                offset
            });
        }
    }

    if line.contains('(') || line.contains(')') {
        return Err(format!("Invalid selection wrapper: {line}"));
    }

    Ok(Selection {
        text: line.to_string(),
        path: line.to_string(),
        aggregate: None,
        limit: Some(25),
        offset: 0
    })
}

fn parse_visibility(line: &str) -> Result<Visibility, String> {
    let line_split = line.split_once(':');
    let value = line_split.ok_or_else(|| {
        format!("Missing colon in visibility: {line}")
    })?.1.trim();

    match value {
        "all" => Ok(Visibility::All),
        "public" => Ok(Visibility::Public),
        "private" => Ok(Visibility::Private),
        _ => Err(format!("visibility must be all, public, or private, got {value}"))
    }
}

fn parse_sort(line: &str, has_sort: bool) -> Result<SortSpec, String> {
    let ascending_path = line.strip_prefix("sort_asc:");
    let descending_path = line.strip_prefix("sort_desc:");
    let (path, descending) = match (ascending_path, descending_path) {
        (Some(path), None) => (path, false),
        (None, Some(path)) => (path, true),
        _ => return Err(format!("Invalid sort: {line}"))
    };
    if has_sort {
        return Err("Only one of sort_asc or sort_desc may be set".to_string());
    }
    let path = path.trim_start().to_string();
    if path.is_empty() {
        return Err("Sort path cannot be empty".to_string());
    }
    if path == "id" {
        return Err("`id` cannot be sorted".to_string());
    }
    if path == "user_id" {
        return Err("`user_id` cannot be sorted".to_string());
    }
    Ok(SortSpec {
        path,
        descending
    })
}

pub fn parse_query(query: &mut Query) -> Result<(), String> {
    query.select.clear();
    query.filters.clear();
    query.visibility = Visibility::All;
    query.sort = None;
    let mut section = None;

    for line in query.query.lines() {
        let stripped = line.trim();
        if stripped.is_empty() {
            continue;
        }
        if stripped == "select:" {
            section = Some("select");
            continue;
        }
        if stripped == "filters:" {
            section = Some("filters");
            continue;
        }
        if stripped.starts_with("visibility:") {
            query.visibility = parse_visibility(stripped)?;
            section = None;
            continue;
        }
        if stripped.starts_with("sort_asc:") || stripped.starts_with("sort_desc:") {
            query.sort = Some(parse_sort(stripped, query.sort.is_some())?);
            section = None;
            continue;
        }

        match section {
            Some("select") => {
                let selection = parse_selection(stripped)?;
                if selection.path == "id" {
                    return Err("`id` cannot be selected".to_string());
                }
                if selection.path == "user_id" {
                    return Err("`user_id` cannot be selected".to_string());
                }
                query.select.push(selection);
            }
            Some("filters") => {
                let filter = parse_filter(stripped)?;
                if filter.path == "id" {
                    return Err("`id` cannot be filtered".to_string());
                }
                if filter.path == "user_id" {
                    return Err("`user_id` cannot be filtered".to_string());
                }
                query.filters.push(filter);
            }
            _ => return Err(format!("Line outside any section: {stripped}"))
        }
    }

    if query.select.is_empty() {
        return Err("Query must select at least one path".to_string());
    }

    Ok(())
}
