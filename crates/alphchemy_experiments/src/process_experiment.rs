use alphchemy_analysis::path::resolve_path;
use alphchemy_engine::experiment::run_variant;
use alphchemy_parse::parse::parse_experiment::parse_experiment::parse_experiment;
use alphchemy_utils::{field_str, field_usize};
use futures_util::FutureExt;
use serde_json::{Value, json};
use supabase_rs::SupabaseClient;
use std::panic::{AssertUnwindSafe, catch_unwind};

use crate::fetch_data::fetch_experiment_data;

pub fn benchmark_score(results: &Value, score_path: &str) -> f64 {
    let result_root = json!({"results": results});
    let Ok(value) = resolve_path(&result_root, score_path) else {
        return 0.0;
    };
    if let Some(flag) = value.as_bool() {
        return if flag { 1.0 } else { 0.0 };
    }
    let Some(number) = value.as_f64() else {
        return 0.0;
    };
    if number.is_finite() { number } else { 0.0 }
}

fn terminal_status(result: &Value) -> &'static str {
    let has_error = matches!(result, Value::Object(_));

    if has_error {
        "errored"
    } else {
        "completed"
    }
}

async fn active_benchmark(client: &SupabaseClient, user_id: &str) -> Result<Option<Value>, String> {
    let query = client.select("benchmarks");
    let query = query.eq("user_id", user_id);
    Ok(query.execute().await?.into_iter().find(|row| {
        row["active_model"].is_string()
    }))
}

async fn record_benchmark(client: &SupabaseClient, user_id: &str, experiment_id: usize, results: &Value) -> Result<(), String> {
    let Some(row) = active_benchmark(client, user_id).await? else { return Ok(()) };

    let benchmark_id = field_usize(&row, "id")?;
    let model = field_str(&row, "active_model")?;
    let score_path = field_str(&row, "score_path")?;
    let score = benchmark_score(results, score_path);

    let experiment_id_string = experiment_id.to_string();
    client.update("experiments", &experiment_id_string, json!({
        "benchmark_data": {
            "benchmark_id": benchmark_id,
            "model": model,
            "score": score
        }
    })).await?;

    let benchmark_id_string = benchmark_id.to_string();
    client.update("benchmarks", &benchmark_id_string, json!({"last_updated": "now"})).await?;
    println!("benchmark id={benchmark_id} model={model} experiment_id={experiment_id} score={score}");

    Ok(())
}

async fn finish(client: &SupabaseClient, row: &Value, results: Value, status: &str) -> Result<(), String> {
    let experiment_id = field_usize(row, "id")?;
    let id = experiment_id.to_string();
    client.update("experiments", &id, json!({
        "status": status,
        "results": results,
        "last_updated": "now"
    })).await?;
    println!("{status} id={id}");

    let Some(user_id) = row["user_id"].as_str() else {
        return Ok(());
    };

    let recorded = record_benchmark(client, user_id, experiment_id, &results).await;
    if let Err(error) = recorded {
        println!("benchmark error id={id}: {error}");
    }

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
            let results = json!({"error": error, "is_internal": false});
            finish(client, &row, results, "errored").await?;
            return Ok(true);
        }
        Err(_) => {
            let results = json!({"error": "internal error", "is_internal": true});
            finish(client, &row, results, "errored").await?;
            return Ok(true);
        }
    };

    client.update("experiments", &id, json!({
        "experiment": variant.to_json(),
        "last_updated": "now"
    })).await?;

    let execution = AssertUnwindSafe(async {
        let data_result = fetch_experiment_data(&variant);
        match data_result {
            Ok(data) => run_variant(&variant, &data).await,
            Err(error) => json!({
                "error": error,
                "is_internal": false
            })
        }
    }).catch_unwind().await;
    let results = match execution {
        Ok(results) => results,
        Err(_) => {
            let results = json!({"error": "internal error", "is_internal": true});
            finish(client, &row, results, "errored").await?;
            return Ok(true);
        }
    };
    let status = terminal_status(&results);
    finish(client, &row, results, status).await?;

    Ok(true)
}
