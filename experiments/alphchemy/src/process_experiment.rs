use crate::experiment::experiment::run_experiment_json;
use serde_json::{Value, json};
use supabase_rs::SupabaseClient;
use std::collections::HashMap;

fn terminal_status(result: &Value) -> &'static str {
    let has_error = match result {
        Value::Object(fields) => fields.contains_key("error"),
        _ => false
    };

    if has_error {
        "errored"
    } else {
        "completed"
    }
}

async fn fetch_next(client: &SupabaseClient) -> Result<Option<Value>, String> {
    let base = client.select("experiments");
    let filtered = base.eq("status", "queued");
    let sorted = filtered.order("created_at", true);
    let rows = sorted.limit(1).execute().await?;
    Ok(rows.into_iter().next())
}

pub async fn process_experiment(client: &SupabaseClient, data: &HashMap<String, Vec<f64>>) -> Result<bool, String> {
    let maybe_row = fetch_next(client).await?;
    let row = match maybe_row {
        Some(value) => value,
        None => return Ok(false)
    };

    let id_value = row.get("id").ok_or_else(|| "missing id".to_string())?;
    let id = id_value.as_i64().ok_or_else(|| "id is not i64".to_string())?.to_string();

    let experiment_value = row.get("experiment");
    let experiment = experiment_value.ok_or_else(|| "missing experiment".to_string())?;

    client.update("experiments", &id, json!({"status": "running"})).await?;
    println!("claimed id={id}");

    let results = run_experiment_json(&experiment, data);
    let status = terminal_status(&results);
    client.update("experiments", &id, json!({
        "status": status,
        "results": results
    })).await?;
    println!("{status} id={id}");

    Ok(true)
}