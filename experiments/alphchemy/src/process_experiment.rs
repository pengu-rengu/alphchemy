use crate::parse::parse_experiment::{parse_experiment, run_variant};
use crate::utils::{field_usize, field_str};
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
    let sorted = filtered.order("last_edited", true);
    let rows = sorted.limit(1).execute().await?;
    Ok(rows.into_iter().next())
}

pub async fn process_experiment(client: &SupabaseClient) -> Result<bool, String> {
    let maybe_row = fetch_next(client).await?;
    let row = match maybe_row {
        Some(value) => value,
        None => return Ok(false)
    };

    let id = field_usize(&row, "id")?.to_string();
    let source = field_str(&row, "source")?;

    client.update("experiments", &id, json!({
        "status": "running",
        "last_edited": "now"
    })).await?;
    println!("claimed id={id}");

    let variant = match parse_experiment(source) {
        Ok(parsed) => parsed,
        Err(error) => {
            println!("parse error id={id}: {error}");
            client.update("experiments", &id, json!({
                "status": "errored",
                "results": {"error": error, "is_internal": false},
                "last_edited": "now"
            })).await?;
            return Ok(true);
        }
    };

    client.update("experiments", &id, json!({
        "experiment": variant.to_json(),
        "last_edited": "now"
    })).await?;

    let results = run_variant(&variant).await;
    let status = terminal_status(&results);
    client.update("experiments", &id, json!({
        "status": status,
        "results": results,
        "last_edited": "now"
    })).await?;
    println!("{status} id={id}");

    Ok(true)
}
