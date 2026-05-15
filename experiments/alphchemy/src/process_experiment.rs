use crate::experiment::experiment::run_experiment_json;
use crate::fetch_data::fetch_btc_ohlc;
use crate::utils::from_field;
use serde_json::{Value, json};
use supabase_rs::SupabaseClient;

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

async fn build_results(experiment: &Value) -> Value {
    let start_result: Result<f64, String> = from_field(experiment, "start_timestamp");
    let start_timestamp = match start_result {
        Ok(value) => value,
        Err(error) => return json!({"error": error, "is_internal": false})
    };

    let end_result: Result<f64, String> = from_field(experiment, "end_timestamp");
    let end_timestamp = match end_result {
        Ok(value) => value,
        Err(error) => return json!({"error": error, "is_internal": false})
    };

    let fetch_result = fetch_btc_ohlc(start_timestamp, end_timestamp).await;
    let data = match fetch_result {
        Ok(value) => value,
        Err(error) => return json!({"error": error, "is_internal": false})
    };

    run_experiment_json(experiment, &data)
}

pub async fn process_experiment(client: &SupabaseClient) -> Result<bool, String> {
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

    let results = build_results(experiment).await;
    let status = terminal_status(&results);
    client.update("experiments", &id, json!({
        "status": status,
        "results": results
    })).await?;
    println!("{status} id={id}");

    Ok(true)
}
