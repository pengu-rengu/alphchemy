use rust_supabase_sdk::SupabaseClient;
use serde::{Deserialize, Serialize};
use serde_json::{Value, to_value};

use crate::format::format_query_results;
use crate::query::Query;

#[derive(Debug, Deserialize, Serialize)]
struct ExperimentQueryRow {
    id: u64,
    last_updated: String,
    title: String,
    experiment: Option<Value>,
    results: Option<Value>,
    status: String,
    user_id: Option<String>,
    is_public: bool
}

pub async fn load_experiments(supabase: &SupabaseClient) -> Result<Vec<Value>, String> {
    let query = supabase.from("experiments");
    let query = query.select("id, last_updated, title, experiment, results, status, user_id, is_public");
    let query = query.eq("status", "completed");
    let query = query.order("last_updated", false);
    let query = query.returns::<ExperimentQueryRow>().execute().await;
    let rows = query.map_err(|error| error.to_string())?;
    rows.into_iter().map(|row| {
        let row_value = to_value(row);
        row_value.map_err(|error| error.to_string())
    }).collect()
}

pub async fn query_experiments(supabase: &SupabaseClient, query_text: &str, user_id: &str) -> Result<String, String> {
    let experiments = load_experiments(supabase).await?;
    let mut query = Query::new(query_text);
    query.run_with_experiments(experiments, user_id)?;
    Ok(format_query_results(&query))
}
