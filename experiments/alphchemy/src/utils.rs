use std::collections::HashMap;
use std::cmp::Ordering;
use ndarray::Array1;
use serde::de::DeserializeOwned;
use serde_json::{Value, from_value};

pub fn parse_json<T: DeserializeOwned>(json: &Value) -> Result<T, String> {
    let result = from_value(json.clone());
    result.map_err(|e| e.to_string())
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

pub fn std_dev(values: &[f64]) -> f64 {
    if values.len() < 2 {
        return 0.0;
    }
    
    let count = values.len() as f64;
    let mean = values.iter().sum::<f64>() / count;

    let squared_diff_fn = |value: &f64| {
        let diff = value - mean;
        diff.powi(2)
    };
    let variance = values.iter().map(squared_diff_fn).sum::<f64>() / (count - 1.0);
    let std = variance.sqrt();

    if std.is_nan() { 
        0.0 
    } else { 
        std 
    }
}

pub fn cmp_f64(a: f64, b: f64) -> Ordering {
    let ordering = a.partial_cmp(&b);
    ordering.unwrap_or(Ordering::Equal)
}

pub fn expect_non_neg(value: f64, field: &str) -> Result<(), String> {
    if value < 0.0 {
        let error_msg = format!("{field} must be >= 0.0");
        return Err(error_msg);
    }
    Ok(())
}

pub fn read_ohlc_data(path: &str) -> Result<(Vec<f64>, HashMap<String, Array1<f64>>), String> {
    let reader = csv::Reader::from_path(path);
    let mut reader = reader.map_err(|err| format!("failed to open {path}: {err}"))?;

    let mut open_vec: Vec<f64> = Vec::new();
    let mut high_vec: Vec<f64> = Vec::new();
    let mut low_vec: Vec<f64> = Vec::new();
    let mut close_vec: Vec<f64> = Vec::new();

    let headers = reader.headers().map_err(|err| format!("failed to read headers: {err}"))?;
    let open_idx = find_col_idx(headers, "open")?;
    let high_idx = find_col_idx(headers, "high")?;
    let low_idx = find_col_idx(headers, "low")?;
    let close_idx = find_col_idx(headers, "close")?;

    for result in reader.records() {
        let record = result.map_err(|err| format!("failed to read row: {err}"))?;

        let open_val = parse_col(&record, open_idx, "open")?;
        open_vec.push(open_val);
        let high_val = parse_col(&record, high_idx, "high")?;
        high_vec.push(high_val);
        let low_val = parse_col(&record, low_idx, "low")?;
        low_vec.push(low_val);
        let close_val = parse_col(&record, close_idx, "close")?;
        close_vec.push(close_val);
    }

    let mut ohlc_data = HashMap::new();
    let open_array = Array1::from_vec(open_vec);
    ohlc_data.insert("open".to_string(), open_array);
    let high_array = Array1::from_vec(high_vec);
    ohlc_data.insert("high".to_string(), high_array);
    let low_array = Array1::from_vec(low_vec);
    ohlc_data.insert("low".to_string(), low_array);
    let close_array = Array1::from_vec(close_vec.clone());
    ohlc_data.insert("close".to_string(), close_array);

    Ok((close_vec, ohlc_data))
}

fn find_col_idx(headers: &csv::StringRecord, col_name: &str) -> Result<usize, String> {
    let position = headers.iter().position(|header| header == col_name);
    position.ok_or_else(|| format!("missing column: {col_name}"))
}

fn parse_col(record: &csv::StringRecord, idx: usize, col_name: &str) -> Result<f64, String> {
    let maybe_field = record.get(idx);
    let field = maybe_field.ok_or_else(|| format!("missing {col_name} value"))?;
    let value = field.parse::<f64>();
    value.map_err(|err| format!("invalid {col_name} value '{field}': {err}"))
}
