use std::collections::HashMap;

use alphchemy_utils::parse_timestamp;
use rust_supabase_sdk::postgrest::PostgrestBuilder;
use rust_supabase_sdk::SupabaseClient;
use serde::Deserialize;
use serde_json::{Value, json};

use crate::format::format_value;

#[derive(Debug, Deserialize)]
struct IdRow {
    id: u64
}

#[derive(Debug, Deserialize)]
struct BenchmarkListRow {
    id: u64,
    title: String,
    cutoff: String,
    active_model: Option<String>
}

#[derive(Default)]
struct BenchmarkModelData {
    scores: Vec<Value>,
    experiment_ids: Vec<u64>
}

#[derive(Debug, Deserialize)]
struct ExperimentBenchmarkData {
    model: String,
    score: Value
}

#[derive(Debug, Deserialize)]
struct BenchmarkExperimentRow {
    id: u64,
    benchmark_data: ExperimentBenchmarkData
}

#[derive(Debug, Deserialize)]
struct BenchmarkRow {
    id: u64,
    last_updated: String,
    title: String,
    score_path: String,
    cutoff: String,
    active_model: Option<String>
}

#[derive(Debug, Deserialize)]
struct ActiveBenchmarkRow {
    id: u64,
    cutoff: String,
    active_model: Option<String>
}

pub struct ActiveBenchmark {
    id: u64,
    cutoff: String,
    model: String
}

impl ActiveBenchmark {
    pub fn apply<T>(&self, query: PostgrestBuilder<T>) -> PostgrestBuilder<T> {
        let model = self.model.replace('\\', "\\\\");
        let model = model.replace('"', "\\\"");
        let model = format!("\"{model}\"");
        let filter = format!("last_updated.lte.{},and(benchmark_data->>benchmark_id.eq.{},benchmark_data->>model.eq.{})", self.cutoff, self.id, model);
        query.or(&filter)
    }
}

pub async fn active_benchmark(supabase: &SupabaseClient, user_id: &str) -> Result<Option<ActiveBenchmark>, String> {
    let query = supabase.from("benchmarks");
    let query = query.select("id, cutoff, active_model");
    let query = query.eq("user_id", user_id);
    let query = query.returns::<ActiveBenchmarkRow>().execute().await;
    let rows = query.map_err(|error| error.to_string())?;
    let active = rows.into_iter().find(|row| row.active_model.is_some());
    let Some(row) = active else {
        return Ok(None);
    };
    let model = row.active_model.ok_or("active benchmark is missing active_model".to_string())?;
    Ok(Some(ActiveBenchmark {
        id: row.id,
        cutoff: row.cutoff,
        model
    }))
}

async fn benchmark_row(supabase: &SupabaseClient, benchmark_id: usize, user_id: &str) -> Result<BenchmarkRow, String> {
    let columns = "id, last_updated, title, score_path, cutoff, active_model";
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

pub async fn create_benchmark(supabase: &SupabaseClient, title: &str, score_path: &str, cutoff: &str, user_id: &str) -> Result<String, String> {
    let parsed = parse_timestamp(cutoff);
    let parsed = parsed.map_err(|_| format!("invalid cutoff: {cutoff}"))?;
    let body = json!({
        "title": title.trim(),
        "score_path": score_path.trim(),
        "cutoff": parsed,
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
    let query = query.select("id, last_updated, title, cutoff, active_model");
    let query = query.eq("user_id", user_id);
    let query = query.order("last_updated", false);
    let query = query.returns::<BenchmarkListRow>().execute().await;
    let rows = query.map_err(|error| error.to_string())?;
    let mut lines = vec![format!("[BENCHMARKS] {} benchmark(s)", rows.len())];
    for row in rows {
        let active_model = row.active_model.unwrap_or_else(|| "none".to_string());
        let cutoff = Value::from(row.cutoff);
        let cutoff = format_value(&cutoff);
        lines.push(format!("id={} title={} cutoff={cutoff} active_model={active_model}", row.id, row.title));
    }
    Ok(lines.join("\n"))
}

pub async fn view_benchmark(supabase: &SupabaseClient, benchmark_id: usize, user_id: &str) -> Result<String, String> {
    let row = benchmark_row(supabase, benchmark_id, user_id).await?;
    let query = supabase.from("experiments");
    let query = query.select("id, benchmark_data");
    let query = query.eq("benchmark_data->>benchmark_id", benchmark_id);
    let query = query.order("last_updated", true);
    let query = query.order("id", true);
    let query = query.returns::<BenchmarkExperimentRow>().execute().await;
    let experiments = query.map_err(|error| error.to_string())?;

    let mut models = HashMap::<String, BenchmarkModelData>::new();
    for experiment in experiments {
        let model_data = models.entry(experiment.benchmark_data.model).or_default();
        model_data.scores.push(experiment.benchmark_data.score);
        model_data.experiment_ids.push(experiment.id);
    }

    let active_model = row.active_model.unwrap_or_else(|| "none".to_string());

    let cutoff = Value::from(row.cutoff);
    let cutoff = format_value(&cutoff);

    let id_line = format!("id: {}", row.id);
    let last_updated_line = format!("last_updated: {}", row.last_updated);
    let title_line = format!("title: {}", row.title);
    let score_path_line = format!("score_path: {}", row.score_path);
    let cutoff_line = format!("cutoff: {cutoff}");
    let active_model_line = format!("active_model: {active_model}");

    let mut lines = vec![id_line, last_updated_line, title_line, score_path_line, cutoff_line, active_model_line];
    for (model, model_data) in models {
        lines.push(format!("[MODEL] {model} {} score(s)", model_data.scores.len()));
        let scores = model_data.scores.iter();
        let scores = scores.map(format_value);
        let scores = scores.collect::<Vec<_>>();
        let scores = scores.join(", ");
        lines.push(format!("scores: {scores}"));

        let experiment_ids = model_data.experiment_ids.iter();
        let experiment_ids = experiment_ids.map(u64::to_string);
        let experiment_ids = experiment_ids.collect::<Vec<_>>();
        let experiment_ids = experiment_ids.join(", ");
        lines.push(format!("experiment_ids: {experiment_ids}"));
    }
    Ok(lines.join("\n"))
}

pub async fn delete_benchmark(supabase: &SupabaseClient, benchmark_id: usize, user_id: &str) -> Result<String, String> {
    benchmark_row(supabase, benchmark_id, user_id).await?;
    let query = supabase.from("experiments");
    let query = query.update(json!({"benchmark_data": null}));
    let query = query.eq("benchmark_data->>benchmark_id", benchmark_id);
    let query = query.execute().await;
    query.map_err(|error| error.to_string())?;

    let query = supabase.from("benchmarks").delete();
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
