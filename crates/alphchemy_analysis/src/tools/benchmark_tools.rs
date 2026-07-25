use rust_supabase_sdk::SupabaseClient;
use serde::Deserialize;
use serde_json::{Value, json};

use crate::filters::parse_timestamp;
use crate::format::format_value;

#[derive(Debug, Deserialize)]
struct IdRow {
    id: u64
}

#[derive(Debug, Deserialize)]
struct BenchmarkListRow {
    id: u64,
    title: String,
    latest_timestamp: String,
    active_model: Option<String>
}

#[derive(Debug, Deserialize)]
struct BenchmarkRow {
    id: u64,
    last_updated: String,
    title: String,
    score_path: String,
    latest_timestamp: String,
    scores: Value,
    active_model: Option<String>
}

#[derive(Debug, Deserialize)]
struct BenchmarkCutoffRow {
    latest_timestamp: String,
    active_model: Option<String>
}

pub async fn active_benchmark_cutoff(supabase: &SupabaseClient, user_id: &str) -> Result<Option<String>, String> {
    let query = supabase.from("benchmarks");
    let query = query.select("latest_timestamp, active_model");
    let query = query.eq("user_id", user_id);
    let query = query.returns::<BenchmarkCutoffRow>().execute().await;
    let rows = query.map_err(|error| error.to_string())?;
    let active = rows.into_iter().find(|row| row.active_model.is_some());
    Ok(active.map(|row| row.latest_timestamp))
}

async fn benchmark_row(supabase: &SupabaseClient, benchmark_id: usize, user_id: &str) -> Result<BenchmarkRow, String> {
    let columns = "id, last_updated, title, score_path, latest_timestamp, scores, active_model";
    let query = supabase.from("benchmarks");
    let query = query.select(columns);
    let query = query.eq("user_id", user_id);
    let query = query.eq("id", benchmark_id);
    let query = query.returns::<BenchmarkRow>().maybe_single().execute().await;
    let row = query.map_err(|error| error.to_string())?;
    row.ok_or_else(|| {
        format!("benchmark id={benchmark_id} not found")
    })
}

pub async fn create_benchmark(supabase: &SupabaseClient, title: &str, score_path: &str, latest_timestamp: &str, user_id: &str) -> Result<String, String> {
    let parsed = parse_timestamp(latest_timestamp);
    let parsed = parsed.map_err(|_| format!("invalid latest_timestamp: {latest_timestamp}"))?;
    let parsed = parsed.format("%Y-%m-%dT%H:%M:%S");
    let body = json!({
        "title": title.trim(),
        "score_path": score_path.trim(),
        "latest_timestamp": parsed.to_string(),
        "scores": {},
        "active_model": null,
        "user_id": user_id
    });
    let query = supabase.from("benchmarks");
    let query = query.insert(body);
    let query = query.select_returning("id");
    let query = query.returns::<IdRow>().single().execute().await;
    let row = query.map_err(|error| error.to_string())?;
    Ok(format!("created benchmark id={}", row.id))
}

pub async fn list_benchmarks(supabase: &SupabaseClient, user_id: &str) -> Result<String, String> {
    let query = supabase.from("benchmarks");
    let query = query.select("id, last_updated, title, latest_timestamp, active_model");
    let query = query.eq("user_id", user_id);
    let query = query.order("last_updated", false);
    let query = query.returns::<BenchmarkListRow>().execute().await;
    let rows = query.map_err(|error| error.to_string())?;
    let mut lines = vec![format!("[BENCHMARKS] {} benchmark(s)", rows.len())];
    for row in rows {
        let active_model = row.active_model.unwrap_or_else(|| "none".to_string());
        let latest_timestamp = Value::from(row.latest_timestamp);
        let latest_timestamp = format_value(&latest_timestamp);
        lines.push(format!("id={} title={} latest_timestamp={latest_timestamp} active_model={active_model}", row.id, row.title));
    }
    Ok(lines.join("\n"))
}

fn format_benchmark(row: BenchmarkRow) -> String {
    let active_model = row.active_model.unwrap_or_else(|| "none".to_string());
    let latest_timestamp = Value::from(row.latest_timestamp);
    let latest_timestamp = format_value(&latest_timestamp);
    let mut lines = vec![format!("id: {}", row.id), format!("last_updated: {}", row.last_updated), format!("title: {}", row.title), format!("score_path: {}", row.score_path), format!("latest_timestamp: {latest_timestamp}"), format!("active_model: {active_model}")];
    let Some(scores) = row.scores.as_object() else {
        return lines.join("\n");
    };
    for (model, values) in scores {
        let values = values.as_array().cloned().unwrap_or_default();
        lines.push(format!("[MODEL] {model} {} score(s)", values.len()));
        let formatted = values.iter().map(format_value).collect::<Vec<_>>().join(", ");
        lines.push(format!("scores: {formatted}"));
    }
    lines.join("\n")
}

pub async fn view_benchmark(supabase: &SupabaseClient, benchmark_id: usize, user_id: &str) -> Result<String, String> {
    let row = benchmark_row(supabase, benchmark_id, user_id).await?;
    Ok(format_benchmark(row))
}

pub async fn delete_benchmark(supabase: &SupabaseClient, benchmark_id: usize, user_id: &str) -> Result<String, String> {
    benchmark_row(supabase, benchmark_id, user_id).await?;
    let query = supabase.from("benchmarks");
    let query = query.delete();
    let query = query.eq("user_id", user_id);
    let query = query.eq("id", benchmark_id).execute().await;
    query.map_err(|error| error.to_string())?;
    Ok(format!("deleted benchmark id={benchmark_id}"))
}

async fn clear_active_models(supabase: &SupabaseClient, user_id: &str) -> Result<(), String> {
    let query = supabase.from("benchmarks");
    let query = query.update(json!({"active_model": null}));
    let query = query.eq("user_id", user_id).execute().await;
    query.map_err(|error| error.to_string())?;
    Ok(())
}

pub async fn disable_benchmark_mode(supabase: &SupabaseClient, user_id: &str) -> Result<String, String> {
    clear_active_models(supabase, user_id).await?;
    Ok("disabled benchmark mode".to_string())
}

pub async fn enable_benchmark_mode(supabase: &SupabaseClient, benchmark_id: usize, model: &str, user_id: &str) -> Result<String, String> {
    benchmark_row(supabase, benchmark_id, user_id).await?;
    clear_active_models(supabase, user_id).await?;
    let query = supabase.from("benchmarks");
    let query = query.update(json!({"active_model": model, "last_updated": "now"}));
    let query = query.eq("user_id", user_id);
    let query = query.eq("id", benchmark_id).execute().await;
    query.map_err(|error| error.to_string())?;
    Ok(format!("enabled benchmark mode id={benchmark_id} model={model}"))
}
