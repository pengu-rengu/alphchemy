use rust_supabase_sdk::SupabaseClient;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json, to_value};

use crate::format::format_value;

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

async fn notebook_row(supabase: &SupabaseClient, notebook_id: usize, user_id: &str) -> Result<NotebookRow, String> {
    let columns = "id, last_updated, title, queries, notes, status, error_message";
    let query = supabase.from("notebooks");
    let query = query.select(columns);
    let query = query.eq("user_id", user_id);
    let query = query.eq("id", notebook_id);
    let query = query.returns::<NotebookRow>().maybe_single().execute().await;
    let row = query.map_err(|error| error.to_string())?;
    row.ok_or_else(|| format!("notebook id={notebook_id} not found"))
}

pub async fn list_notebooks(supabase: &SupabaseClient, user_id: &str) -> Result<String, String> {
    let query = supabase.from("notebooks");
    let query = query.select("id, last_updated, title");
    let query = query.eq("user_id", user_id);
    let query = query.order("last_updated", false);
    let query = query.returns::<NotebookListRow>().execute().await;
    let rows = query.map_err(|error| error.to_string())?;
    let mut lines = vec![format!("[NOTEBOOKS] {} notebook(s)", rows.len())];
    for row in rows {
        lines.push(format!("id={} title={}", row.id, row.title));
    }
    Ok(lines.join("\n"))
}

fn format_notebook(row: NotebookRow) -> String{
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
    lines.join("\n")
}

pub async fn view_notebook(supabase: &SupabaseClient, notebook_id: usize, user_id: &str) -> Result<String, String> {
    let row = notebook_row(supabase, notebook_id, user_id).await?;
    Ok(format_notebook(row))
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
    let query = supabase.from("notebooks");
    let query = query.insert(body);
    let query = query.select_returning("id");
    let query = query.returns::<IdRow>().single().execute().await;
    let row = query.map_err(|error| error.to_string())?;
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
    let query = supabase.from("notebooks");
    let query = query.update(values);
    let query = query.eq("user_id", user_id);
    let query = query.eq("id", notebook_id).execute().await;
    query.map_err(|error| error.to_string())?;
    Ok(format!("updated notebook id={notebook_id}"))
}

pub async fn delete_notebook(supabase: &SupabaseClient, notebook_id: usize, user_id: &str) -> Result<String, String> {
    notebook_row(supabase, notebook_id, user_id).await?;
    let query = supabase.from("notebooks");
    let query = query.delete();
    let query = query.eq("user_id", user_id);
    let query = query.eq("id", notebook_id).execute().await;
    query.map_err(|error| error.to_string())?;
    Ok(format!("deleted notebook id={notebook_id}"))
}
