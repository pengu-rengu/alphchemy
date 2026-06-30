use std::cmp::Ordering;
use serde::Serialize;
use serde_json::{Value, to_value};

// Serialize a struct, then add a string tag field (e.g. "type" or "feature").
pub fn to_json_with_tag<T: Serialize>(object: &T, key: &str, tag: &str) -> Value {
    let mut json = to_value(object).unwrap();
    if let Value::Object(map) = &mut json {
        let string_value = Value::String(tag.to_string());
        map.insert(key.to_string(), string_value);
    }
    json
}

pub fn safe_divide(a: f64, b: f64) -> f64 {
    if b == 0.0 {
        return 0.0;
    }

    a / b
}

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

pub fn field_string(json: &Value, key: &str) -> Result<String, String> {
    let text = field_str(json, key)?;
    Ok(text.to_string())
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
