use crate::parse::parse_experiment::{parse_experiment, run_variant};
use crate::utils::{field_usize, field_str};
use futures_util::FutureExt;
use serde_json::{Value, json};
use supabase_rs::SupabaseClient;
use std::panic::{AssertUnwindSafe, catch_unwind};

fn terminal_status(result: &Value) -> &'static str {
    let has_error = matches!(result, Value::Object(_));

    if has_error {
        "errored"
    } else {
        "completed"
    }
}

async fn save_error(
    client: &SupabaseClient,
    id: &str,
    error: &str,
    is_internal: bool
) -> Result<(), String> {
    let update = client.update("experiments", id, json!({
        "status": "errored",
        "results": {
            "error": error,
            "is_internal": is_internal
        },
        "last_updated": "now"
    }));
    update.await?;
    Ok(())
}

async fn fetch_next(client: &SupabaseClient) -> Result<Option<Value>, String> {
    let base = client.select("experiments");
    let filtered = base.eq("status", "queued");
    let sorted = filtered.order("last_updated", true);
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
        "last_updated": "now"
    })).await?;
    println!("claimed id={id}");

    let parsed = catch_unwind(AssertUnwindSafe(|| parse_experiment(source)));
    let variant = match parsed {
        Ok(Ok(variant)) => variant,
        Ok(Err(error)) => {
            println!("parse error id={id}: {error}");
            save_error(client, &id, &error, false).await?;
            return Ok(true);
        }
        Err(_) => {
            save_error(client, &id, "internal error", true).await?;
            return Ok(true);
        }
    };

    client.update("experiments", &id, json!({
        "experiment": variant.to_json(),
        "last_updated": "now"
    })).await?;

    let execution = AssertUnwindSafe(run_variant(&variant)).catch_unwind().await;
    let results = match execution {
        Ok(results) => results,
        Err(_) => {
            save_error(client, &id, "internal error", true).await?;
            return Ok(true);
        }
    };
    let status = terminal_status(&results);
    client.update("experiments", &id, json!({
        "status": status,
        "results": results,
        "last_updated": "now"
    })).await?;
    println!("{status} id={id}");

    Ok(true)
}
