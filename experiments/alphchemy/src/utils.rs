use std::cmp::Ordering;
use serde::de::DeserializeOwned;
use serde_json::{Value, from_value};

pub fn std_dev(values: &[f64]) -> f64 {
    if values.len() < 2 {
        return 0.0;
    }
    
    let count = values.len() as f64;
    let mean = values.iter().sum::<f64>() / count;

    let mut squared_diff_sum = 0.0;

    for value in values {
        let diff = value - mean;
        let squared_diff = diff.powi(2);
        squared_diff_sum += squared_diff;
    }

    let sample_count = count - 1.0;
    let variance = squared_diff_sum / sample_count;
    variance.sqrt()
}

pub fn compare_f64(a: f64, b: f64) -> Ordering {
    let ordering = a.partial_cmp(&b);
    ordering.unwrap_or(Ordering::Equal)
}

pub fn parse_json<T: DeserializeOwned>(json: &Value) -> Result<T, String> {
    let result = from_value(json.clone());
    result.map_err(|error| error.to_string())
}

pub fn get_field<'a>(json: &'a Value, field: &str) -> Result<&'a Value, String> {
    let maybe_value = json.get(field);
    maybe_value.ok_or_else(|| format!("missing {field}"))
}

pub fn from_field<T: DeserializeOwned>(json: &Value, field: &str) -> Result<T, String> {
    let value = get_field(json, field)?;
    let result = from_value::<T>(value.clone());

    result.map_err(|error| format!("{field}: {error}"))
}

pub fn expect_non_neg(value: f64, field: &str) -> Result<(), String> {
    if value < 0.0 {
        return Err(format!("{field} must be >= 0.0"));
    }
    Ok(())
}

pub fn expect_type(json: &Value, expected_type: &str, label: &str) -> Result<(), String> {
    let type_str = get_field(json, "type")?.as_str().unwrap_or_default();

    if type_str != expected_type {
        return Err(format!("{label} type must be {expected_type}"));
    }

    Ok(())
}
