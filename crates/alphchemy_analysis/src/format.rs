use chrono::{DateTime, NaiveDateTime};
use serde_json::Value;

use crate::query::Query;

fn trim_decimal(mut text: String) -> String {
    if text.contains('.') {
        while text.ends_with('0') {
            text.pop();
        }
        if text.ends_with('.') {
            text.pop();
        }
    }
    if text == "-0" {
        return "0".to_string();
    }
    text
}

pub fn format_raw_value(value: &Value) -> String {
    if let Some(text) = value.as_str() {
        return text.to_string();
    }
    if let Some(flag) = value.as_bool() {
        return if flag { "True".to_string() } else { "False".to_string() };
    }
    if value.is_null() {
        return "None".to_string();
    }
    let Some(number) = value.as_f64() else {
        return value.to_string();
    };
    if number == 0.0 {
        return "0".to_string();
    }

    let exponent = number.abs().log10().floor() as i32;
    if !(-4..3).contains(&exponent) {
        let scientific = format!("{number:.2e}");
        let Some((coefficient, exponent_text)) = scientific.split_once('e') else {
            return scientific;
        };
        let coefficient = trim_decimal(coefficient.to_string());
        let exponent_value = exponent_text.parse::<i32>().unwrap_or(exponent);
        return format!("{coefficient}e{exponent_value:+03}");
    }

    let decimal_places = (2 - exponent).max(0) as usize;
    trim_decimal(format!("{number:.decimal_places$}"))
}

pub fn format_value(value: &Value) -> String {
    if let Some(text) = value.as_str() {
        if let Ok(parsed) = DateTime::parse_from_rfc3339(text) {
            return parsed.format("%b %-d %Y %H:%M").to_string();
        }
        if let Ok(parsed) = NaiveDateTime::parse_from_str(text, "%Y-%m-%dT%H:%M:%S%.f") {
            return parsed.format("%b %-d %Y %H:%M").to_string();
        }
        return text.to_string();
    }
    format_raw_value(value)
}

pub fn format_query_results(query: &Query) -> String {
    let results = query.results.as_deref().unwrap_or_default();
    let mut lines = vec![format!("[QUERY] {} path(s)", results.len())];

    for result in results {
        let mut pairs = Vec::new();
        for (i, value) in result.values.iter().enumerate() {
            let formatted = format_value(value);
            if result.ids.is_empty() {
                pairs.push(formatted);
            } else {
                pairs.push(format!("{formatted} ({})", result.ids[i]));
            }
        }

        lines.push(String::new());
        lines.push(format!("[RESULTS] {}", result.path));
        let joined = if pairs.is_empty() { "—".to_string() } else { pairs.join(", ") };
        lines.push(joined);
        if result.skipped > 0 {
            lines.push(format!("skipped: {}", result.skipped));
        }
    }

    format!("{}\n\n", lines.join("\n"))
}
