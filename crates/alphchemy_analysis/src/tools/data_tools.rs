use serde::Deserialize;
use serde_json::{Value, from_str};
use tokio::fs::read_to_string;

use crate::format::format_value;

const DATA_ROOT: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../../data");

#[derive(Debug, Deserialize)]
struct PriceData {
    timestamps: Vec<String>,
    close: Vec<f64>
}

async fn read_data(symbol: &str) -> Result<PriceData, String> {
    let path = format!("{DATA_ROOT}/{symbol}.json");
    let body = read_to_string(path).await;
    let body = match body {
        Ok(body) => body,
        Err(error) => return Err(error.to_string())
    };
    let data = from_str::<PriceData>(&body);
    match data {
        Ok(data) => Ok(data),
        Err(error) => Err(error.to_string())
    }
}

pub async fn avg_price(symbol: &str) -> Result<String, String> {
    let data = read_data(symbol).await?;
    let value = Value::from(data.close.iter().sum::<f64>() / data.close.len() as f64);
    Ok(format!("Average close price for {symbol}: {}", format_value(&value)))
}

pub async fn data_range(symbol: &str) -> Result<String, String> {
    let data = read_data(symbol).await?;
    let first = data.timestamps.first().ok_or_else(|| format!("no bars found for symbol {symbol}"))?;
    let last = data.timestamps.last().ok_or_else(|| format!("no bars found for symbol {symbol}"))?;
    Ok(format!("{first} -> {last}"))
}
