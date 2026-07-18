use std::env::var;
use std::path::Path;

use rust_supabase_sdk::SupabaseClient;
use serde::Deserialize;
use serde_json::{Value, from_str};
use tokio::fs::read_to_string;

use crate::format::format_raw_value;

#[derive(Debug, Deserialize)]
struct ApiKeyRow {
    user_id: String
}

#[derive(Debug, Deserialize)]
struct PriceData {
    close: Vec<f64>
}

pub fn supabase_from_env() -> Result<SupabaseClient, String> {
    let supabase_url = var("SUPABASE_URL");
    let supabase_url = supabase_url.map_err(|error| error.to_string())?;
    let supabase_key = var("SUPABASE_KEY");
    let supabase_key = supabase_key.map_err(|error| error.to_string())?;
    Ok(SupabaseClient::new(supabase_url, supabase_key, None))
}

pub async fn find_user_id(supabase: &SupabaseClient, api_key: &str) -> Result<String, String> {
    let rows = supabase.from("api_keys").select("user_id").eq("api_key", api_key).limit(1).returns::<ApiKeyRow>().execute().await;
    let mut rows = rows.map_err(|error| error.to_string())?;
    let row = rows.pop().ok_or("Invalid API key".to_string())?;
    Ok(row.user_id)
}

pub async fn avg_price(data_root: &Path, symbol: &str) -> Result<String, String> {
    let path = data_root.join(format!("{symbol}.json"));
    let body = read_to_string(path).await.map_err(|error| error.to_string())?;
    let data = from_str::<PriceData>(&body).map_err(|error| error.to_string())?;
    let total = data.close.iter().sum::<f64>();
    let average = total / data.close.len() as f64;
    let value = Value::from(average);
    Ok(format!("Average close price for {symbol}: {}", format_raw_value(&value)))
}
