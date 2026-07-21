use chrono::{DateTime, NaiveDate, NaiveDateTime, ParseError};
use serde_json::Value;

use crate::path::resolve_path;

const DATETIME_FORMATS: [&str; 7] = [
    "%Y-%m-%dT%H:%M:%S%.f", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%b %d %Y %H:%M", "%Y-%m-%d %H:%M", "%b %d %Y"
];

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
    if let Ok(parsed) = DateTime::parse_from_rfc3339(value) {
        return Ok(parsed.naive_utc());
    }

    for format in DATETIME_FORMATS {
        if let Ok(parsed) = NaiveDateTime::parse_from_str(value, format) {
            return Ok(parsed);
        }
    }

    let date = NaiveDate::parse_from_str(value, "%Y-%m-%d")?;
    Ok(date.and_hms_opt(0, 0, 0).unwrap())
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
