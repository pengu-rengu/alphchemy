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

    (squared_diff_sum / (count - 1.0)).sqrt()
}
