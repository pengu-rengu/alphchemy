use serde_json::{Value, json};
use supabase_rs::SupabaseClient;

use crate::experiment::experiment::parse_experiment;
use crate::actions::actions::Action;
use crate::pinescript::to_ps::experiment_to_pinescript;
use crate::utils::{get_field, parse_json};

async fn fetch_next(client: &SupabaseClient) -> Result<Option<Value>, String> {
    let base = client.select("pinescript_jobs");
    let filtered = base.eq("status", "working");
    let sorted = filtered.order("created_at", true);
    let limited = sorted.limit(1);
    let rows = limited.execute().await?;
    let mut iter = rows.into_iter();
    Ok(iter.next())
}

async fn fetch_experiment(client: &SupabaseClient, experiment_id: i64) -> Result<Value, String> {
    let base = client.select("experiments");
    let filtered = base.eq("id", &experiment_id.to_string());
    let limited = filtered.limit(1);
    let rows = limited.execute().await?;
    let mut iter = rows.into_iter();
    let maybe_row = iter.next();
    maybe_row.ok_or_else(|| format!("parent experiment {experiment_id} not found"))
}

fn extract_best_val_seq(results: &Value, fold_idx: usize) -> Result<Vec<Action>, String> {
    let maybe_fold = results.get(fold_idx);
    let fold_results = maybe_fold.ok_or_else(|| format!("fold_idx {fold_idx} out of range"))?;
    let opt_results = get_field(fold_results, "opt_results")?;
    let best_val_seq_json = get_field(opt_results, "best_val_seq")?;
    parse_json::<Vec<Action>>(best_val_seq_json)
}

fn generate_pinescript(experiment_row: &Value, fold_idx: usize) -> Result<String, String> {
    let maybe_status_value = experiment_row.get("status");
    let maybe_status_str = maybe_status_value.and_then(|value| value.as_str());
    let status = maybe_status_str.ok_or_else(|| "parent experiment missing status".to_string())?;
    if status != "completed" {
        return Err(format!("experiment status is {status}, expected completed"));
    }

    let results = get_field(experiment_row, "results")?;
    if let Some(object) = results.as_object() && object.contains_key("error") {
        return Err("experiment results contains error".to_string());
    }

    let maybe_title_value = experiment_row.get("title");
    let maybe_title_str = maybe_title_value.and_then(|value| value.as_str());
    let title = maybe_title_str.ok_or_else(|| "experiment row missing title".to_string())?;

    let experiment_json = get_field(experiment_row, "experiment")?;
    let experiment = parse_experiment(experiment_json)?;
    let best_val_seq = extract_best_val_seq(results, fold_idx)?;

    experiment_to_pinescript(&experiment, title, fold_idx, &best_val_seq)
}

pub async fn process_pinescript(client: &SupabaseClient) -> Result<bool, String> {
    let maybe_row = fetch_next(client).await?;
    let row = match maybe_row {
        Some(value) => value,
        None => return Ok(false)
    };

    let maybe_id_value = row.get("id");
    let id_value = maybe_id_value.ok_or_else(|| "pinescript_jobs row missing id".to_string())?;
    let maybe_id = id_value.as_i64();
    let id_int = maybe_id.ok_or_else(|| "pinescript_jobs id is not i64".to_string())?;
    let id = id_int.to_string();

    let maybe_exp_id_value = row.get("experiment_id");
    let maybe_exp_id_int = maybe_exp_id_value.and_then(|value| value.as_i64());
    let experiment_id = maybe_exp_id_int.ok_or_else(|| "pinescript_jobs row missing experiment_id".to_string())?;

    let maybe_fold_value = row.get("fold_idx");
    let maybe_fold_int = maybe_fold_value.and_then(|value| value.as_i64());
    let fold_idx_int = maybe_fold_int.ok_or_else(|| "pinescript_jobs row missing fold_idx".to_string())?;
    let fold_idx_try = usize::try_from(fold_idx_int);
    let fold_idx = fold_idx_try.map_err(|error| error.to_string())?;

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
                "status": "completed"
            })).await?;
            println!("completed pinescript_jobs id={id}");
        }
        Err(error) => {
            println!("pinescript_jobs failed id={id}: {error}");
            let _ = client.update("pinescript_jobs", &id, json!({
                "error_message": error,
                "status": "errored"
            })).await;
        }
    }
    Ok(true)
}
