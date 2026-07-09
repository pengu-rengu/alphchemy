use serde_json::Value;
use std::collections::HashMap;
use std::fs;

use crate::features::features::TimestampedTable;

const DATA_DIR: &str = "../../data";

fn extract_series(data: &Value, name: &str) -> Result<Vec<f64>, String> {
    let maybe_field = data.get(name);
    let field = maybe_field.ok_or_else(|| {
        format!("missing {name} field")
    })?;

    let maybe_array = field.as_array();
    let array = maybe_array.ok_or_else(|| format!("invalid {name} array"))?;

    let mut series = Vec::with_capacity(array.len());
    for value in array.iter() {
        let maybe_number = value.as_f64();
        let number = maybe_number.ok_or_else(|| format!("invalid {name} value: {value}"))?;
        series.push(number);
    }
    Ok(series)
}

fn extract_timestamps(data: &Value) -> Result<Vec<String>, String> {
    let maybe_field = data.get("timestamps");
    let field = maybe_field.ok_or_else(|| "missing timestamps field".to_string())?;

    let maybe_array = field.as_array();
    let array = maybe_array.ok_or_else(|| "invalid timestamps array".to_string())?;

    let mut timestamps = Vec::with_capacity(array.len());
    for value in array.iter() {
        let maybe_str = value.as_str();
        let text = maybe_str.ok_or_else(|| format!("invalid timestamp value: {value}"))?;
        timestamps.push(text.to_string());
    }
    Ok(timestamps)
}

// Reads prefetched CoinAPI OHLC for `symbol` (e.g. "BTC_USDT") from the repo-root `data` folder.
// Assumes the runner is launched from `experiments/alphchemy`, so `../../data` points at it.
pub fn fetch_ohlc(symbol: &str, start_timestamp: &str, end_timestamp: &str) -> Result<TimestampedTable, String> {
    let path = format!("{DATA_DIR}/{symbol}.json");

    let read_result = fs::read_to_string(&path);
    let contents = read_result.map_err(|error| format!("missing data for symbol {symbol} at {path}: {error}"))?;

    let parse_result = serde_json::from_str::<Value>(&contents);
    let data = parse_result.map_err(|error| format!("invalid json in {path}: {error}"))?;

    let timestamps = extract_timestamps(&data)?;
    let open = extract_series(&data, "open")?;
    let high = extract_series(&data, "high")?;
    let low = extract_series(&data, "low")?;
    let close = extract_series(&data, "close")?;

    let mut kept_timestamps = Vec::new();
    let mut kept_open = Vec::new();
    let mut kept_high = Vec::new();
    let mut kept_low = Vec::new();
    let mut kept_close = Vec::new();

    // ISO timestamp strings compare lexicographically in chronological order.
    for (idx, timestamp) in timestamps.iter().enumerate() {
        if timestamp.as_str() < start_timestamp {
            continue;
        }
        if timestamp.as_str() > end_timestamp {
            continue;
        }
        kept_timestamps.push(timestamp.clone());
        kept_open.push(open[idx]);
        kept_high.push(high[idx]);
        kept_low.push(low[idx]);
        kept_close.push(close[idx]);
    }

    if kept_timestamps.is_empty() {
        return Err("no OHLC data returned for requested timestamp range".to_string());
    }

    let mut table = HashMap::new();
    table.insert("open".to_string(), kept_open);
    table.insert("high".to_string(), kept_high);
    table.insert("low".to_string(), kept_low);
    table.insert("close".to_string(), kept_close);

    Ok(TimestampedTable { timestamps: kept_timestamps, table })
}
