use serde_json::{Value, json};
use supabase_rs::SupabaseClient;

use crate::parse::parse_experiment::parse_experiment;
use crate::utils::{field_usize, field_str};

async fn fetch_next(client: &SupabaseClient) -> Result<Option<Value>, String> {
    let base = client.select("validation_jobs");
    let filtered = base.eq("status", "working");
    let sorted = filtered.order("last_updated", true);
    let limited = sorted.limit(1);
    Ok(limited.execute().await?.into_iter().next())
}

pub async fn process_validation(client: &SupabaseClient) -> Result<bool, String> {
    let maybe_row = fetch_next(client).await?;
    let row = match maybe_row {
        Some(value) => value,
        None => return Ok(false)
    };

    let id = field_usize(&row, "id")?.to_string();
    let source = field_str(&row, "source")?;
    println!("processing validation_jobs id={id}");

    match parse_experiment(source) {
        Ok(_) => {
            client.update("validation_jobs", &id, json!({
                "status": "completed_valid",
                "result_message": "Source is valid",
                "last_updated": "now"
            })).await?;
            println!("valid validation_jobs id={id}");
        }
        Err(error) => {
            client.update("validation_jobs", &id, json!({
                "status": "completed_invalid",
                "result_message": error,
                "last_updated": "now"
            })).await?;
            println!("invalid validation_jobs id={id}: {error}");
        }
    }
    Ok(true)
}
