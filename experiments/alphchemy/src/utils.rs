use serde::de::DeserializeOwned;
use serde_json::{Value, from_value};

pub fn parse_json<T: DeserializeOwned>(json: &Value) -> Result<T, String> {
    let result = from_value(json.clone());
    result.map_err(|e| e.to_string())
}

pub fn get_field<'a>(json: &'a Value, field: &str) -> Result<&'a Value, String> {
    json.get(field).ok_or_else(|| format!("missing {field}"))
}

pub fn from_field<T: DeserializeOwned>(json: &Value, field: &str) -> Result<T, String> {
    let value = get_field(json, field)?;
    from_value(value.clone()).map_err(|e| format!("{field}: {e}"))
}

pub fn expect_non_neg(value: f64, field: &str) -> Result<(), String> {
    if value < 0.0 { return Err(format!("{field} must be >= 0.0")); }
    Ok(())
}
