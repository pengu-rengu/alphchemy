use chrono::{DateTime, NaiveDate, NaiveDateTime};
use serde_json::Value;

const ISO_FORMAT: &str = "%Y-%m-%dT%H:%M:%S";
const DATETIME_FORMATS: [&str; 7] = [
    "%Y-%m-%dT%H:%M:%S%.f", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%b %d %Y %H:%M", "%Y-%m-%d %H:%M", "%b %d %Y"
];

pub fn parse_timestamp(text: &str) -> Result<String, String> {
    if let Ok(parsed) = DateTime::parse_from_rfc3339(text) {
        let naive = parsed.naive_utc();
        return Ok(naive.format(ISO_FORMAT).to_string());
    }

    for format in DATETIME_FORMATS {
        if let Ok(naive) = NaiveDateTime::parse_from_str(text, format) {
            return Ok(naive.format(ISO_FORMAT).to_string());
        }
    }

    if let Ok(date) = NaiveDate::parse_from_str(text, "%Y-%m-%d") {
        let naive = date.and_hms_opt(0, 0, 0).unwrap();
        return Ok(naive.format(ISO_FORMAT).to_string());
    }

    Err(format!("invalid timestamp: {text}"))
}

pub fn get_field<'a>(json: &'a Value, key: &str) -> Result<&'a Value, String> {
    let maybe_value = json.get(key);
    maybe_value.ok_or_else(|| format!("missing {key}"))
}

pub fn field_f64(json: &Value, key: &str) -> Result<f64, String> {
    let maybe_value = get_field(json, key)?.as_f64();
    maybe_value.ok_or_else(|| format!("{key} must be f64"))
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
    Ok(field_str(json, key)?.to_string())
}

pub fn field_array<'a>(json: &'a Value, key: &str) -> Result<&'a Vec<Value>, String> {
    let maybe_value = get_field(json, key)?.as_array();
    maybe_value.ok_or_else(|| format!("{key} must be array"))
}
