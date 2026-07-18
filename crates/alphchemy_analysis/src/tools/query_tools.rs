use super::super::*;
use serde_json::to_value;

pub(super) async fn load_experiments(supabase: &SupabaseClient) -> Result<Vec<Value>> {
    let columns = "id, last_updated, title, experiment, results, status, user_id, is_public";
    let rows = supabase.from("experiments").select(columns).eq("status", "completed").order("last_updated", false).returns::<ExperimentQueryRow>().execute().await;
    let rows = rows.map_err(|error| error.to_string())?;
    rows.into_iter().map(|row| to_value(row).map_err(|error| error.to_string())).collect()
}

pub async fn query_experiments(supabase: &SupabaseClient, query_text: &str, user_id: &str) -> Result<String> {
    let experiments = load_experiments(supabase).await?;
    let mut query = Query::new(query_text);
    query.run_with_experiments(experiments, user_id)?;
    Ok(format_query_results(&query))
}
