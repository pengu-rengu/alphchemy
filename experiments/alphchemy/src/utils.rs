use std::cmp::Ordering;
use serde::{Deserialize, Deserializer};
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

pub fn require_nullable<'de, D, T>(deserializer: D) -> Result<Option<T>, D::Error>
where
    D: Deserializer<'de>,
    T: Deserialize<'de>,
{
    Option::<T>::deserialize(deserializer)
}

pub fn get_field<'a>(json: &'a Value, key: &str) -> Result<&'a Value, String> {
    json.get(key).ok_or_else(|| format!("missing {key}"))
}

pub fn field_f64(json: &Value, key: &str) -> Result<f64, String> {
    get_field(json, key)?.as_f64().ok_or_else(|| format!("{key} must be f64"))
}

pub fn field_usize(json: &Value, key: &str) -> Result<usize, String> {
    let maybe_value = get_field(json, key)?.as_u64();
    let value = maybe_value.ok_or_else(|| format!("{key} must be u64"))?;
    Ok(value as usize)
}

pub fn field_str<'a>(json: &'a Value, key: &str) -> Result<&'a str, String> {
    let maybe_value = get_field(json, key)?.as_str();
    maybe_value.ok_or_else(|| format!("{key} must be string"))
}

pub fn field_array<'a>(json: &'a Value, key: &str) -> Result<&'a Vec<Value>, String> {
    let maybe_valuye = get_field(json, key)?.as_array();
    maybe_valuye.ok_or_else(|| format!("{key} must be array"))
}

pub fn validate_identifier(id: &str, field: &str) -> Result<(), String> {
    if id.is_empty() {
        return Err(format!("{field} must not be empty"));
    }
    for character in id.chars() {
        if !character.is_ascii_alphanumeric() && character != '_' {
            return Err(format!("{field} {id} contains invalid pinescript identifier character {character}"));
        }
    }
    Ok(())
}

pub fn expect_non_neg(value: f64, field: &str) -> Result<(), String> {
    if value < 0.0 {
        return Err(format!("{field} must be >= 0.0"));
    }
    Ok(())
}

pub fn expect_type(json: &Value, expected_type: &str, label: &str) -> Result<(), String> {
    if field_str(json, "type")? != expected_type {
        return Err(format!("{label} type must be {expected_type}"));
    }

    Ok(())
}
