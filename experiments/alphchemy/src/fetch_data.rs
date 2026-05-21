use chrono::DateTime;
use chrono::Utc;
use reqwest::Client;
use serde_json::Value;
use std::collections::HashMap;
use std::env;

const SYMBOL: &str = "BINANCE_SPOT_BTC_USDT";
const PERIOD: &str = "1HRS";
const LIMIT: usize = 100000;
const COINAPI_URL: &str = "https://rest.coinapi.io/v1/ohlcv";

fn extract_field(bar: &Value, name: &str) -> Result<f64, String> {
    let maybe_field = bar.get(name);
    let field = maybe_field.ok_or_else(|| format!("missing {name} field"))?;

    let maybe_value = field.as_f64();
    maybe_value.ok_or_else(|| format!("invalid {name} value: {field}"))
}

fn extract_timestamp(bar: &Value, name: &str) -> Result<f64, String> {
    let maybe_field = bar.get(name);
    let field = maybe_field.ok_or_else(|| format!("missing {name} field"))?;

    let maybe_str = field.as_str();
    let iso = maybe_str.ok_or_else(|| format!("invalid {name} value: {field}"))?;

    let parsed = DateTime::parse_from_rfc3339(iso);
    let datetime = parsed.map_err(|error| format!("invalid {name} datetime: {error}"))?;
    let secs = datetime.timestamp();
    Ok(secs as f64)
}

fn timestamp_to_iso(timestamp: f64) -> String {
    let secs = timestamp as i64;
    let maybe_datetime = DateTime::<Utc>::from_timestamp(secs, 0);
    let datetime = maybe_datetime.unwrap();
    let formatted = datetime.format("%Y-%m-%dT%H:%M:%S");
    formatted.to_string()
}

fn bars_to_ohlc_data(bars: &[Value]) -> Result<HashMap<String, Vec<f64>>, String> {
    if bars.is_empty() {
        return Err("no OHLC data returned for requested timestamp range".to_string());
    }

    let n_bars = bars.len();
    let mut timestamp = Vec::with_capacity(n_bars);
    let mut open = Vec::with_capacity(n_bars);
    let mut high = Vec::with_capacity(n_bars);
    let mut low = Vec::with_capacity(n_bars);
    let mut close = Vec::with_capacity(n_bars);

    for bar in bars.iter() {
        let timestamp_val = extract_timestamp(bar, "time_period_start")?;
        timestamp.push(timestamp_val);

        let open_val = extract_field(bar, "price_open")?;
        open.push(open_val);

        let high_val = extract_field(bar, "price_high")?;
        high.push(high_val);

        let low_val = extract_field(bar, "price_low")?;
        low.push(low_val);

        let close_val = extract_field(bar, "price_close")?;
        close.push(close_val);
    }

    let mut data = HashMap::new();
    data.insert("timestamp".to_string(), timestamp);
    data.insert("open".to_string(), open);
    data.insert("high".to_string(), high);
    data.insert("low".to_string(), low);
    data.insert("close".to_string(), close);

    Ok(data)
}

pub async fn fetch_btc_ohlc(start_timestamp: f64, end_timestamp: f64) -> Result<HashMap<String, Vec<f64>>, String> {
    let key_result = env::var("COINAPI_KEY");
    let key = key_result.map_err(|error| format!("missing COINAPI_KEY: {error}"))?;

    let time_start = timestamp_to_iso(start_timestamp);
    let time_end = timestamp_to_iso(end_timestamp);
    let url = format!("{COINAPI_URL}/{SYMBOL}/history?period_id={PERIOD}&time_start={time_start}&time_end={time_end}&limit={LIMIT}");

    let client = Client::new();
    let request = client.get(url).header("Accept", "application/json").header("X-CoinAPI-Key", key);
    let send_result = request.send().await;
    let response = send_result.map_err(|error| format!("coinapi request failed: {error}"))?;

    let status = response.status();
    if !status.is_success() {
        let body_result = response.text().await;
        let body = body_result.unwrap_or_else(|error| format!("<no body: {error}>"));
        return Err(format!("coinapi {status}: {body}"));
    }

    let json_result = response.json::<Vec<Value>>().await;
    let bars = json_result.map_err(|error| format!("invalid coinapi json: {error}"))?;
    bars_to_ohlc_data(&bars)
}
