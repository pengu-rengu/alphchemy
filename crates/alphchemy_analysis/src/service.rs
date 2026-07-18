use std::env::var;
use std::path::Path;
use std::time::Duration;

use rust_supabase_sdk::SupabaseClient;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::{Value, from_str, json};
use tokio::fs::read_to_string;

use crate::analysis::Result;
use crate::format::{format_query_results, format_raw_value, format_value};
use crate::path::resolve_path;
use crate::query::Query;

#[path = "tools/mod.rs"]
mod tools;

pub use tools::{convert, create_notebook, delete_experiment, delete_notebook, experiment_paths, experiment_source, experiment_summary, list_experiments, list_notebooks, process_working_notebook, query_experiments, queue_experiment, queue_validated, results_summary, status, update_notebook, validate_experiment, view_notebook};

const VALIDATION_POLL: Duration = Duration::from_secs(1);
const VALIDATION_TIMEOUT_SEC: u64 = 60;
const PINESCRIPT_POLL: Duration = Duration::from_secs(2);
const PINESCRIPT_TIMEOUT_SEC: u64 = 120;

#[derive(Debug, Deserialize)]
struct IdRow {
    id: i64
}

#[derive(Debug, Deserialize)]
struct ApiKeyRow {
    user_id: String
}

#[derive(Debug, Deserialize, Serialize)]
struct ExperimentQueryRow {
    id: i64,
    last_updated: String,
    title: String,
    experiment: Option<Value>,
    results: Option<Value>,
    status: String,
    user_id: Option<String>,
    is_public: bool
}

#[derive(Debug, Deserialize)]
struct ExperimentListRow {
    id: i64,
    title: String,
    status: String
}

#[derive(Debug, Deserialize)]
struct ExperimentStatusRow {
    id: i64,
    status: String
}

#[derive(Debug, Deserialize)]
struct ExperimentSourceRow {
    source: String
}

#[derive(Debug, Deserialize)]
struct ExperimentSummaryRow {
    id: i64,
    title: String,
    status: String,
    experiment: Value
}

#[derive(Debug, Deserialize)]
struct ResultsSummaryRow {
    id: i64,
    title: String,
    status: String,
    results: Option<Value>
}

#[derive(Debug, Deserialize, Serialize)]
struct ExperimentPathsRow {
    id: i64,
    last_updated: String,
    title: String,
    status: String,
    experiment: Option<Value>,
    results: Option<Value>
}

#[derive(Debug, Deserialize)]
struct ValidationRow {
    source: Option<String>,
    status: String,
    result_message: Option<String>
}

#[derive(Debug, Deserialize)]
struct ConvertRow {
    status: String,
    pinescript: Option<String>,
    error_message: Option<String>
}

#[derive(Debug, Deserialize)]
struct NotebookListRow {
    id: i64,
    title: String
}

#[derive(Debug, Deserialize)]
struct NotebookRow {
    id: i64,
    last_updated: String,
    title: String,
    queries: Vec<Value>,
    notes: Vec<String>,
    status: String,
    error_message: Option<String>
}

#[derive(Debug, Deserialize)]
struct WorkingNotebookRow {
    id: i64,
    queries: Vec<Value>,
    user_id: String
}

#[derive(Debug, Deserialize)]
struct PriceData {
    close: Vec<f64>
}

pub fn supabase_from_env() -> Result<SupabaseClient> {
    let supabase_url = var("SUPABASE_URL");
    let supabase_url = supabase_url.map_err(|error| error.to_string())?;
    let supabase_key = var("SUPABASE_KEY");
    let supabase_key = supabase_key.map_err(|error| error.to_string())?;
    Ok(SupabaseClient::new(supabase_url, supabase_key, None))
}

pub async fn find_user_id(supabase: &SupabaseClient, api_key: &str) -> Result<String> {
    let rows = supabase.from("api_keys").select("user_id").eq("api_key", api_key).limit(1).returns::<ApiKeyRow>().execute().await;
    let mut rows = rows.map_err(|error| error.to_string())?;
    let row = rows.pop().ok_or("Invalid API key".to_string())?;
    Ok(row.user_id)
}

pub async fn avg_price(data_root: &Path, symbol: &str) -> Result<String> {
    let path = data_root.join(format!("{symbol}.json"));
    let body = read_to_string(path).await.map_err(|error| error.to_string())?;
    let data = from_str::<PriceData>(&body).map_err(|error| error.to_string())?;
    let total = data.close.iter().sum::<f64>();
    let average = total / data.close.len() as f64;
    let value = Value::from(average);
    Ok(format!("Average close price for {symbol}: {}", format_raw_value(&value)))
}
