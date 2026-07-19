use std::collections::HashMap;

use chrono::{Duration, NaiveDateTime};
use serde_json::{Value, json};
use supabase_rs::SupabaseClient;

use alphchemy_engine::actions::actions::Action;
use alphchemy_engine::experiment::experiment::ExperimentVariant;
use alphchemy_parse::parse::parse_actions::parse_action;
use alphchemy_parse::parse::parse_experiment::parse_experiment;
use alphchemy_parse::utils::{field_array, field_str, field_string, field_usize, get_field};
use crate::pinescript::to_pinescript::{experiment_to_pinescript, FoldPeriods, ISO_TIMESTAMP_FORMAT};

// Parse a results-json best-sequence (array of action-label strings) back into
// actions. Reads the stored results jsonb to rebuild the optimized network.
fn parse_action_values(values: &[Value], meta_actions: Option<&HashMap<String, Vec<Action>>>) -> Result<Vec<Action>, String> {
    let mut actions = Vec::with_capacity(values.len());

    for value in values {
        let label = value.as_str().ok_or_else(|| "action must be a string".to_string())?;
        let action = parse_action(label, meta_actions)?;
        actions.push(action);
    }

    Ok(actions)
}

async fn fetch_next(client: &SupabaseClient) -> Result<Option<Value>, String> {
    let base = client.select("convert_jobs");
    let filtered = base.eq("status", "working");
    let sorted = filtered.order("last_updated", true);
    let limited = sorted.limit(1);
    Ok(limited.execute().await?.into_iter().next())
}

async fn fetch_experiment(client: &SupabaseClient, experiment_id: usize) -> Result<Value, String> {
    let base = client.select("experiments");
    let filtered = base.eq("id", &experiment_id.to_string());
    let limited = filtered.limit(1);
    limited.execute().await?.into_iter().next().ok_or_else(|| format!("experiment {experiment_id} not found"))
}

pub fn shifted_period_start(start_timestamp: &str, end_timestamp: &str, start_offset: usize) -> Result<String, String> {
    let parsed_start = NaiveDateTime::parse_from_str(start_timestamp, ISO_TIMESTAMP_FORMAT);
    let start = parsed_start.map_err(|error| format!("invalid timestamp {start_timestamp}: {error}"))?;

    let parsed_end = NaiveDateTime::parse_from_str(end_timestamp, ISO_TIMESTAMP_FORMAT);
    let end = parsed_end.map_err(|error| format!("invalid timestamp {end_timestamp}: {error}"))?;

    let offset_hours = start_offset as i64;
    let duration = Duration::hours(offset_hours);
    let maybe_shifted = start.checked_add_signed(duration);
    let shifted = maybe_shifted.ok_or_else(|| format!("start_offset {start_offset} exceeds supported timestamp range"))?;

    if shifted > end {
        return Err(format!("start_offset {start_offset} exceeds period ending {end_timestamp}"));
    }

    let formatted = shifted.format(ISO_TIMESTAMP_FORMAT);
    Ok(formatted.to_string())
}

fn build_fold_periods(fold: &Value, start_offset: usize) -> Result<FoldPeriods, String> {
    let train_start_timestamp = field_string(fold, "train_start_timestamp")?;
    let train_end_timestamp = field_string(fold, "train_end_timestamp")?;
    let val_start_timestamp = field_string(fold, "val_start_timestamp")?;
    let val_end_timestamp = field_string(fold, "val_end_timestamp")?;
    let test_fold_start = field_string(fold, "test_start_timestamp")?;
    let test_end_timestamp = field_string(fold, "test_end_timestamp")?;
    let test_start_timestamp = shifted_period_start(&test_fold_start, &test_end_timestamp, start_offset)?;

    let periods = FoldPeriods {
        train_start_timestamp,
        train_end_timestamp,
        val_start_timestamp,
        val_end_timestamp,
        test_start_timestamp,
        test_end_timestamp
    };
    Ok(periods)
}

fn generate_pinescript(experiment_row: &Value, fold_idx: usize) -> Result<String, String> {
    let status = field_str(experiment_row, "status")?;
    if status != "completed" {
        return Err(format!("experiment status is {status}, expected completed"));
    }

    let title = field_str(experiment_row, "title")?;
    let source = field_str(experiment_row, "source")?;
    let experiment = parse_experiment(source)?;
    let start_offset = match &experiment {
        ExperimentVariant::Logic(exp) => exp.backtest_schema.start_offset,
        ExperimentVariant::Decision(exp) => exp.backtest_schema.start_offset
    };

    let results = field_array(experiment_row, "results")?;
    let fold = results.get(fold_idx).ok_or_else(|| format!("fold_idx {fold_idx} out of range"))?;

    let periods = build_fold_periods(fold, start_offset)?;
    let opt_results = get_field(fold, "opt_results")?;
    let seq_values = field_array(opt_results, "best_val_seq")?;
    let best_val_seq = match &experiment {
        ExperimentVariant::Logic(exp) => parse_action_values(seq_values, Some(&exp.strategy.actions.meta_actions)),
        ExperimentVariant::Decision(exp) => parse_action_values(seq_values, Some(&exp.strategy.actions.meta_actions))
    }?;

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

    println!("processing convert_jobs id={id}");

    let experiment_result = fetch_experiment(client, experiment_id).await;
    let result = match experiment_result {
        Ok(experiment_row) => generate_pinescript(&experiment_row, fold_idx),
        Err(error) => Err(error)
    };

    match result {
        Ok(pinescript) => {
            client.update("convert_jobs", &id, json!({
                "pinescript": pinescript,
                "status": "completed",
                "last_updated": "now"
            })).await?;
            println!("completed convert_jobs id={id}");
        }
        Err(error) => {
            println!("convert_jobs failed id={id}: {error}");
            let _ = client.update("convert_jobs", &id, json!({
                "error_message": error,
                "status": "errored",
                "last_updated": "now"
            })).await;
        }
    }
    Ok(true)
}
