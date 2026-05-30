use serde_json::{Value, json};
use supabase_rs::SupabaseClient;

use crate::experiment::experiment::parse_experiment;
use crate::actions::actions::Action;
use crate::pinescript::to_pinescript::{experiment_to_pinescript, FoldPeriods};
use crate::utils::{parse_json, get_field, field_usize, field_str, field_array};

async fn fetch_next(client: &SupabaseClient) -> Result<Option<Value>, String> {
    let base = client.select("pinescript_jobs");
    let filtered = base.eq("status", "working");
    let sorted = filtered.order("last_edited", true);
    let limited = sorted.limit(1);
    Ok(limited.execute().await?.into_iter().next())
}

async fn fetch_experiment(client: &SupabaseClient, experiment_id: usize) -> Result<Value, String> {
    let base = client.select("experiments");
    let filtered = base.eq("id", &experiment_id.to_string());
    let limited = filtered.limit(1);
    limited.execute().await?.into_iter().next().ok_or_else(|| format!("experiment {experiment_id} not found"))
}

fn generate_pinescript(experiment_row: &Value, fold_idx: usize) -> Result<String, String> {
    let status = field_str(experiment_row, "status")?;
    if status != "completed" {
        return Err(format!("experiment status is {status}, expected completed"));
    }

    let title = field_str(experiment_row, "title")?;
    let experiment = parse_experiment(get_field(experiment_row, "experiment")?)?;

    let results = field_array(experiment_row, "results")?;
    let fold = results.get(fold_idx).ok_or_else(|| format!("fold_idx {fold_idx} out of range"))?;

    let periods = parse_json::<FoldPeriods>(fold)?;
    let opt_results = get_field(fold, "opt_results")?;
    let best_val_seq = parse_json::<Vec<Action>>(get_field(opt_results, "best_val_seq")?)?;

    experiment_to_pinescript(&experiment, title, &best_val_seq, &periods)
}

pub async fn process_pinescript(client: &SupabaseClient) -> Result<bool, String> {
    let maybe_row = fetch_next(client).await?;
    let row = match maybe_row {
        Some(value) => value,
        None => return Ok(false)
    };

    let id = field_usize(&row, "id")?.to_string();
    let experiment_id = field_usize(&row, "experiment_id")?;
    let fold_idx = field_usize(&row, "fold_idx")?;

    println!("processing pinescript_jobs id={id}");

    let experiment_result = fetch_experiment(client, experiment_id).await;
    let result = match experiment_result {
        Ok(experiment_row) => generate_pinescript(&experiment_row, fold_idx),
        Err(error) => Err(error)
    };

    match result {
        Ok(pinescript) => {
            client.update("pinescript_jobs", &id, json!({
                "pinescript": pinescript,
                "status": "completed",
                "last_edited": "now"
            })).await?;
            println!("completed pinescript_jobs id={id}");
        }
        Err(error) => {
            println!("pinescript_jobs failed id={id}: {error}");
            let _ = client.update("pinescript_jobs", &id, json!({
                "error_message": error,
                "status": "errored",
                "last_edited": "now"
            })).await;
        }
    }
    Ok(true)
}
