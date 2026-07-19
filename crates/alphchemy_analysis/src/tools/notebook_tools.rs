use rust_supabase_sdk::SupabaseClient;
use serde::{Deserialize, Serialize};
use serde_json::{Value, from_value, json, to_value};

use crate::format::format_value;
use crate::query::Query;

use super::query_tools::load_experiments;

#[derive(Debug, Deserialize)]
struct IdRow {
    id: u64
}

#[derive(Debug, Deserialize)]
struct NotebookListRow {
    id: u64,
    title: String
}

#[derive(Debug, Deserialize)]
struct NotebookRow {
    id: u64,
    last_updated: String,
    title: String,
    queries: Vec<Value>,
    notes: Vec<String>,
    status: String,
    error_message: Option<String>
}

#[derive(Debug, Deserialize)]
struct WorkingNotebookRow {
    id: u64,
    queries: Vec<Value>,
    user_id: String
}

async fn notebook_row(supabase: &SupabaseClient, notebook_id: usize, user_id: &str) -> Result<NotebookRow, String> {
    let columns = "id, last_updated, title, queries, notes, status, error_message";
    let rows = supabase.from("notebooks").select(columns).eq("user_id", user_id).eq("id", notebook_id).limit(1).returns::<NotebookRow>().execute().await;
    let mut rows = rows.map_err(|error| error.to_string())?;
    rows.pop().ok_or_else(|| format!("notebook id={notebook_id} not found"))
}

pub async fn list_notebooks(supabase: &SupabaseClient, user_id: &str) -> Result<String, String> {
    let rows = supabase.from("notebooks").select("id, last_updated, title").eq("user_id", user_id).order("last_updated", false).returns::<NotebookListRow>().execute().await;
    let rows = rows.map_err(|error| error.to_string())?;
    let mut lines = vec![format!("[NOTEBOOKS] {} notebook(s)", rows.len())];
    for row in rows {
        lines.push(format!("id={} title={}", row.id, row.title));
    }
    Ok(lines.join("\n"))
}

pub async fn view_notebook(supabase: &SupabaseClient, notebook_id: usize, user_id: &str) -> Result<String, String> {
    let row = notebook_row(supabase, notebook_id, user_id).await?;
    let mut lines = vec![format!("id: {}", row.id), format!("last_updated: {}", row.last_updated), format!("title: {}", row.title), format!("status: {}", row.status)];
    if let Some(message) = row.error_message.filter(|message| !message.is_empty()) {
        lines.push(message);
    }
    lines.push(format!("tile_count: {}", row.queries.len()));
    for (i, query) in row.queries.iter().enumerate() {
        lines.push(format!("[TILE {i}]"));
        lines.push("query:".to_string());
        lines.push(query["query"].as_str().unwrap_or_default().to_string());
        lines.push(format!("note: {}", row.notes[i]));
        let Some(results) = query["results"].as_array() else {
            continue;
        };
        if results.is_empty() {
            continue;
        }
        lines.push("results:".to_string());
        for result in results {
            lines.push(format!("path: {}", result["path"].as_str().unwrap_or_default()));
            let values = result["values"].as_array().cloned().unwrap_or_default();
            let formatted = values.iter().map(format_value).collect::<Vec<_>>().join(", ");
            lines.push(format!("values: {formatted}"));
            lines.push(format!("skipped: {}", format_value(&result["skipped"])));
        }
    }
    Ok(lines.join("\n"))
}

fn validate_notebook_parts(queries: &[impl Serialize], notes: &[String]) -> Result<(), String> {
    if queries.len() != notes.len() {
        return Err("queries and notes must have the same length".to_string());
    }
    Ok(())
}

pub async fn create_notebook(supabase: &SupabaseClient, title: &str, queries: &[String], notes: &[String], user_id: &str) -> Result<String, String> {
    validate_notebook_parts(queries, notes)?;
    let status = if queries.is_empty() { "idle" } else { "working" };
    let queries = queries.iter().map(|query| json!({"query": query, "results": null})).collect::<Vec<_>>();
    let body = json!({
        "title": title.trim(),
        "queries": queries,
        "notes": notes,
        "status": status,
        "error_message": null,
        "user_id": user_id
    });
    let rows = supabase.from("notebooks").insert(body).select_returning("id").returns::<IdRow>().execute().await;
    let row = rows.map_err(|error| error.to_string())?.into_iter().next().ok_or("notebook insert returned no row".to_string())?;
    Ok(format!("created notebook id={}", row.id))
}

pub async fn update_notebook(supabase: &SupabaseClient, notebook_id: usize, title: Option<&str>, queries: Option<&[String]>, notes: Option<&[String]>, user_id: &str) -> Result<String, String> {
    let notebook = notebook_row(supabase, notebook_id, user_id).await?;
    let cleared_queries = notebook.queries.into_iter().map(|mut query| {
        query["results"] = Value::Null;
        query
    }).collect::<Vec<_>>();
    let mut values = json!({
        "queries": cleared_queries,
        "status": "working",
        "error_message": null,
        "last_updated": "now"
    });
    if let Some(title) = title {
        values["title"] = Value::from(title.trim());
    }
    if let Some(queries) = queries {
        let Some(notes) = notes else {
            return Err("notes must be provided when queries are replaced".to_string());
        };
        validate_notebook_parts(queries, notes)?;
        values["queries"] = Value::Array(queries.iter().map(|query| json!({"query": query, "results": null})).collect());
        values["notes"] = to_value(notes).map_err(|error| error.to_string())?;
    } else if let Some(notes) = notes {
        validate_notebook_parts(&notebook.notes, notes)?;
        values["notes"] = to_value(notes).map_err(|error| error.to_string())?;
    }
    let updated = supabase.from("notebooks").update(values).eq("user_id", user_id).eq("id", notebook_id).execute().await;
    updated.map_err(|error| error.to_string())?;
    Ok(format!("updated notebook id={notebook_id}"))
}

pub async fn delete_notebook(supabase: &SupabaseClient, notebook_id: usize, user_id: &str) -> Result<String, String> {
    notebook_row(supabase, notebook_id, user_id).await?;
    let deleted = supabase.from("notebooks").delete().eq("user_id", user_id).eq("id", notebook_id).execute().await;
    deleted.map_err(|error| error.to_string())?;
    Ok(format!("deleted notebook id={notebook_id}"))
}

async fn write_idle_notebook(supabase: &SupabaseClient, notebook_id: u64, queries: Vec<Value>) -> Result<(), String> {
    let body = json!({"queries": queries, "status": "idle", "error_message": null, "last_updated": "now"});
    let updated = supabase.from("notebooks").update(body).eq("id", notebook_id).execute().await;
    updated.map_err(|error| error.to_string())?;
    Ok(())
}

async fn write_errored_notebook(supabase: &SupabaseClient, notebook_id: u64, message: &str) -> Result<(), String> {
    let body = json!({"status": "errored", "error_message": message, "last_updated": "now"});
    let updated = supabase.from("notebooks").update(body).eq("id", notebook_id).execute().await;
    updated.map_err(|error| error.to_string())?;
    Ok(())
}

async fn run_queries(supabase: &SupabaseClient, queries: Vec<Value>, user_id: &str) -> Result<Vec<Value>, String> {
    let experiments = load_experiments(supabase).await?;
    let mut results = Vec::new();
    for mut entry in queries {
        entry.as_object_mut().ok_or("notebook query must be an object".to_string())?.remove("results");
        let mut query = from_value::<Query>(entry).map_err(|error| error.to_string())?;
        query.run_with_experiments(experiments.clone(), user_id)?;
        results.push(to_value(query).map_err(|error| error.to_string())?);
    }
    Ok(results)
}

pub async fn process_working_notebook(supabase: &SupabaseClient) -> Result<bool, String> {
    let rows = supabase.from("notebooks").select("id, queries, user_id").eq("status", "working").order("last_updated", true).limit(1).returns::<WorkingNotebookRow>().execute().await;
    let mut rows = rows.map_err(|error| error.to_string())?;
    let Some(row) = rows.pop() else {
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
