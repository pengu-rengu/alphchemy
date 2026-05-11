use reqwest::Client;
use serde_json::Value;
use std::collections::HashMap;
use std::env;

const SYMBOL: &str = "BINANCE_SPOT_BTC_USDT";
const PERIOD: &str = "1HRS";
const LIMIT: usize = 1000;
const COINAPI_URL: &str = "https://rest.coinapi.io/v1/ohlcv";

fn extract_field(bar: &Value, name: &str) -> Result<f64, String> {
    let maybe_field = bar.get(name);
    let field = maybe_field.ok_or_else(|| format!("missing {name} field"))?;

    let maybe_value = field.as_f64();
    maybe_value.ok_or_else(|| format!("invalid {name} value: {field}"))
}

pub async fn fetch_btc_ohlc() -> Result<HashMap<String, Vec<f64>>, String> {
    let key_result = env::var("COINAPI_KEY");
    let key = key_result.map_err(|error| format!("missing COINAPI_KEY: {error}"))?;

    let url = format!("{COINAPI_URL}/{SYMBOL}/latest?period_id={PERIOD}&limit={LIMIT}");

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

    let mut open = Vec::with_capacity(bars.len());
    let mut high = Vec::with_capacity(bars.len());
    let mut low = Vec::with_capacity(bars.len());
    let mut close = Vec::with_capacity(bars.len());

    for bar in bars.iter().rev() {
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
    data.insert("open".to_string(), open);
    data.insert("high".to_string(), high);
    data.insert("low".to_string(), low);
    data.insert("close".to_string(), close);

    Ok(data)
}
