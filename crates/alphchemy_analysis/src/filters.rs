use chrono::{DateTime, NaiveDateTime, ParseError};
use serde_json::Value;

use crate::path::resolve_path;

#[derive(Clone, Debug, PartialEq)]
pub(crate) enum FilterValue {
    Number(f64),
    Text(String),
    Bool(bool),
    Timestamp(NaiveDateTime)
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) enum FilterOperator {
    Equal,
    GreaterEqual,
    Greater,
    LessEqual,
    Less
}

#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Filter {
    pub path: String,
    pub operator: FilterOperator,
    pub value: FilterValue
}

pub(crate) fn parse_timestamp(value: &str) -> Result<NaiveDateTime, ParseError> {
    let timestamp = if let Some(stripped) = value.strip_suffix('Z') {
        format!("{stripped}+00:00")
    } else {
        value.to_string()
    };

    if let Ok(parsed) = DateTime::parse_from_rfc3339(&timestamp) {
        return Ok(parsed.naive_utc());
    }
    if let Ok(parsed) = NaiveDateTime::parse_from_str(value, "%Y-%m-%dT%H:%M:%S%.f") {
        return Ok(parsed);
    }

    NaiveDateTime::parse_from_str(value, "%b %e %Y %H:%M")
}

fn compare_ordered<T: PartialOrd + PartialEq>(actual: T, expected: T, operator: FilterOperator) -> bool {
    match operator {
        FilterOperator::Equal => actual == expected,
        FilterOperator::GreaterEqual => actual >= expected,
        FilterOperator::Greater => actual > expected,
        FilterOperator::LessEqual => actual <= expected,
        FilterOperator::Less => actual < expected
    }
}

fn check_filter(value: &Value, filter: &Filter) -> bool {
    match &filter.value {
        FilterValue::Number(expected) => {
            if value.is_boolean() {
                return false;
            }
            let Some(actual) = value.as_f64() else {
                return false;
            };
            compare_ordered(actual, *expected, filter.operator)
        }
        FilterValue::Text(expected) => {
            let Some(actual) = value.as_str() else {
                return false;
            };
            filter.operator == FilterOperator::Equal && actual == expected
        }
        FilterValue::Bool(expected) => {
            let Some(actual) = value.as_bool() else {
                return false;
            };
            filter.operator == FilterOperator::Equal && actual == *expected
        }
        FilterValue::Timestamp(expected) => {
            let Some(text) = value.as_str() else {
                return false;
            };
            let Ok(actual) = parse_timestamp(text) else {
                return false;
            };
            compare_ordered(actual, *expected, filter.operator)
        }
    }
}

pub(crate) fn matches_filters(object: &Value, filters: &[Filter]) -> Result<bool, String> {
    for filter in filters {
        let resolved = resolve_path(object, &filter.path)?;
        if !check_filter(&resolved, filter) {
            return Ok(false);
        }
    }

    Ok(true)
}
