use std::env::var;
use std::time::Duration;

use alphchemy_analysis::{
    query::Query,
    tools::query_tools::load_experiments
};
use rust_supabase_sdk::SupabaseClient;
use serde::{Deserialize};
use serde_json::{Value, from_value, json, to_value};
use tokio::time::sleep;

#[derive(Debug, Deserialize)]
struct WorkingNotebookRow {
    id: u64,
    queries: Vec<Value>,
    user_id: String
}


async fn write_idle_notebook(supabase: &SupabaseClient, notebook_id: u64, queries: Vec<Value>) -> Result<(), String> {
    let body = json!({
        "queries": queries,
        "status": "idle",
        "error_message": null,
        "last_updated": "now"
    });
    let query = supabase.from("notebooks");
    let query = query.update(body);
    let query = query.eq("id", notebook_id).execute().await;
    query.map_err(|error| error.to_string())?;
    Ok(())
}

async fn write_errored_notebook(supabase: &SupabaseClient, notebook_id: u64, message: &str) -> Result<(), String> {
    let body = json!({
        "status": "errored",
        "error_message": message,
        "last_updated": "now"
    });
    let query = supabase.from("notebooks");
    let query = query.update(body);
    let query = query.eq("id", notebook_id).execute().await;
    query.map_err(|error| error.to_string())?;
    Ok(())
}

async fn run_queries(supabase: &SupabaseClient, queries: Vec<Value>, user_id: &str) -> Result<Vec<Value>, String> {
    let experiments = load_experiments(supabase).await?;
    let mut results = Vec::new();

    for mut entry in queries {
        let entry_object = entry.as_object_mut().ok_or("notebook query must be an object".to_string())?;
        entry_object.remove("results");

        let query = from_value::<Query>(entry);
        let mut query = query.map_err(|error| error.to_string())?;
        query.run(experiments.clone(), user_id)?;

        let query_value = to_value(query);
        let query_value = query_value.map_err(|error| error.to_string())?;
        results.push(query_value);
    }
    Ok(results)
}


pub async fn process_notebook(supabase: &SupabaseClient) -> Result<bool, String> {
    let query = supabase.from("notebooks");
    let query = query.select("id, queries, user_id");
    let query = query.eq("status", "working");
    let query = query.order("last_updated", true);
    let query = query.limit(1);
    let query = query.returns::<WorkingNotebookRow>().execute().await;

    let Some(row) = query.map_err(|error| error.to_string())?.pop() else {
        return Ok(false);
    };

    println!("running notebook id={}", row.id);
    match run_queries(supabase, row.queries, &row.user_id).await {
        Ok(queries) => {
            write_idle_notebook(supabase, row.id, queries).await?;
            println!("completed notebook id={}", row.id);
        }
        Err(error) => {
            println!("notebook run failed id={}: {error}", row.id);
            write_errored_notebook(supabase, row.id, &error.to_string()).await?;
        }
    }
    Ok(true)
}


#[tokio::main]
async fn main() {
    let supabase_url = var("SUPABASE_URL");
    let supabase_url = supabase_url.map_err(|error| error.to_string()).unwrap();

    let supabase_key = var("SUPABASE_KEY");
    let supabase_key = supabase_key.map_err(|error| error.to_string()).unwrap();

    let supabase = SupabaseClient::new(supabase_url, supabase_key, None);

    loop {
        let handled = match process_notebook(&supabase).await {
            Ok(value) => value,
            Err(error) => {
                println!("{error}");
                false
            }
        };
        if handled {
            continue;
        }

        println!("idle");
        let duration = Duration::from_secs(2);
        sleep(duration).await;
    }
}
