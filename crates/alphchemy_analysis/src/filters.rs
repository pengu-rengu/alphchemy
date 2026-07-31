use alphchemy_utils::parse_timestamp;
use serde_json::Value;

use crate::path::resolve_path;

#[derive(Clone, Debug, PartialEq)]
pub(crate) enum FilterValue {
    Number(f64),
    Text(String),
    Bool(bool),
    Timestamp(String)
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
            compare_ordered(&actual, expected, filter.operator)
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
