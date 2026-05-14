use std::collections::HashMap;

use serde_json::{json, Value};
use supabase_rs::SupabaseClient;

use crate::features::features::{feat_table, parse_feats};

pub fn feature_set_values(feats_json: &Value, data: &HashMap<String, Vec<f64>>) -> Result<Value, String> {
    let feature_jsons = feats_json.as_array().ok_or_else(|| "features must be array".to_string())?;
    let feats = parse_feats(feature_jsons)?;
    let feat_values = feat_table(&feats, data);
    let open = data.get("open").ok_or_else(|| "missing open data".to_string())?;
    let high = data.get("high").ok_or_else(|| "missing high data".to_string())?;
    let low = data.get("low").ok_or_else(|| "missing low data".to_string())?;
    let close = data.get("close").ok_or_else(|| "missing close data".to_string())?;

    Ok(json!({
        "ohlc": {
            "open": open,
            "high": high,
            "low": low,
            "close": close
        },
        "features": feat_values
    }))
}

async fn fetch_next(client: &SupabaseClient) -> Result<Option<Value>, String> {
    let base = client.select("feature_sets");
    let filtered = base.eq("status", "working");
    let sorted = filtered.order("last_edited", true);
    let rows = sorted.limit(1).execute().await?;

    Ok(rows.into_iter().next())
}

pub async fn process_feature_set(client: &SupabaseClient, data: &HashMap<String, Vec<f64>>) -> Result<bool, String> {
    let maybe_row = fetch_next(client).await?;
    let row = match maybe_row {
        Some(value) => value,
        None => return Ok(false)
    };

    let id_value = row.get("id").ok_or_else(|| "feature set row missing id".to_string())?;
    let id = id_value.as_i64().ok_or_else(|| "feature set row id is not i64".to_string())?.to_string();
    let feats_value = row.get("features");

    println!("processing feature_set id={id}");

    let result = match feats_value {
        Some(value) => feature_set_values(value, data),
        None => Err("missing features".to_string())
    };

    match result {
        Ok(values) => {
            client.update("feature_sets", &id, json!({
                "values": values,
                "status": "fulfilled"
            })).await?;
            println!("fulfilled feature_set id={id}");
        }
        Err(error) => {
            println!("feature set failed id={id}: {error}");
            let status_result = client.update("feature_sets", &id, json!({
                "status": "errored"
            })).await;
            if let Err(status_error) = status_result {
                println!("feature set status update failed id={id}: {status_error}");
            }
        }
    }
    Ok(true)
}
