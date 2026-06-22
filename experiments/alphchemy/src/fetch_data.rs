use reqwest::Client;
use serde_json::Value;
use std::collections::HashMap;
use std::env;

use crate::features::features::TimestampedTable;

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

fn extract_timestamp(bar: &Value, name: &str) -> Result<String, String> {
    let maybe_field = bar.get(name);
    let field = maybe_field.ok_or_else(|| format!("missing {name} field"))?;

    let maybe_str = field.as_str();
    let iso = maybe_str.ok_or_else(|| format!("invalid {name} value: {field}"))?;
    Ok(iso.to_string())
}

fn bars_to_ohlc_data(bars: &[Value]) -> Result<TimestampedTable, String> {
    if bars.is_empty() {
        return Err("no OHLC data returned for requested timestamp range".to_string());
    }

    let n_bars = bars.len();
    let mut timestamps = Vec::with_capacity(n_bars);
    let mut open = Vec::with_capacity(n_bars);
    let mut high = Vec::with_capacity(n_bars);
    let mut low = Vec::with_capacity(n_bars);
    let mut close = Vec::with_capacity(n_bars);

    for bar in bars.iter() {
        let timestamp_val = extract_timestamp(bar, "time_period_start")?;
        timestamps.push(timestamp_val);

        let open_val = extract_field(bar, "price_open")?;
        open.push(open_val);

        let high_val = extract_field(bar, "price_high")?;
        high.push(high_val);

        let low_val = extract_field(bar, "price_low")?;
        low.push(low_val);

        let close_val = extract_field(bar, "price_close")?;
        close.push(close_val);
    }

    let mut table = HashMap::new();
    table.insert("open".to_string(), open);
    table.insert("high".to_string(), high);
    table.insert("low".to_string(), low);
    table.insert("close".to_string(), close);

    Ok(TimestampedTable { timestamps, table })
}

pub async fn fetch_btc_ohlc(start_timestamp: &str, end_timestamp: &str) -> Result<TimestampedTable, String> {
    let key_result = env::var("COINAPI_KEY");
    let key = key_result.map_err(|error| format!("missing COINAPI_KEY: {error}"))?;

    let url = format!("{COINAPI_URL}/{SYMBOL}/history?period_id={PERIOD}&time_start={start_timestamp}&time_end={end_timestamp}&limit={LIMIT}");

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
