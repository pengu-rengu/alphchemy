use alphchemy::experiment::experiment::run_experiment_json;
use alphchemy::fetch_data::fetch_btc_ohlc;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::time::Duration;
use std::env;
use tokio::time::sleep;
use supabase_rs::SupabaseClient;

const POLL_INTERVAL: Duration = Duration::from_secs(2);

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

async fn process_one(client: &SupabaseClient, data: &HashMap<String, Vec<f64>>) -> Result<bool, String> {
    let maybe_row = fetch_next(client).await?;
    let row = match maybe_row {
        Some(value) => value,
        None => return Ok(false)
    };

    let maybe_id = row.get("id");
    let id_value = maybe_id.ok_or_else(|| "missing id".to_string())?;
    let id_number = id_value.as_i64().ok_or_else(|| "id is not i64".to_string())?;
    let id = id_number.to_string();

    let experiment_value = row.get("experiment").cloned();
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

#[tokio::main]
async fn main() {
    let data = fetch_btc_ohlc().await.unwrap();

    let url = env::var("SUPABASE_URL").unwrap();
    let key = env::var("SUPABASE_KEY").unwrap();
    let client = SupabaseClient::new(url, key).unwrap();

    loop {
        let result = process_one(&client, &data).await;
        let next  = match result {
            Ok(value) => value,
            Err(error) => {
                println!("{}", error);
                false
            }
        };
        if next {
            continue;
        }

        println!("idle");
        sleep(POLL_INTERVAL).await;
    }
}
