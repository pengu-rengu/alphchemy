use super::super::*;
use serde_json::to_value;
use tokio::time::sleep;

async fn accessible_row<T>(supabase: &SupabaseClient, experiment_id: i64, columns: &str, user_id: &str) -> Result<T>
where
    T: DeserializeOwned + Send + 'static
{
    let access_filter = format!("is_public.eq.true,user_id.eq.{user_id}");
    let rows = supabase.from("experiments").select(columns).or(&access_filter).eq("id", experiment_id).limit(1).returns::<T>().execute().await;
    let mut rows = rows.map_err(|error| error.to_string())?;
    rows.pop().ok_or_else(|| format!("experiment id={experiment_id} not found"))
}

async fn require_owned_experiment(supabase: &SupabaseClient, experiment_id: i64, user_id: &str) -> Result<()> {
    let rows = supabase.from("experiments").select("id").eq("user_id", user_id).eq("id", experiment_id).limit(1).returns::<IdRow>().execute().await;
    let rows = rows.map_err(|error| error.to_string())?;
    if rows.is_empty() {
        return Err(format!("experiment id={experiment_id} not found"));
    }
    Ok(())
}

pub async fn queue_experiment(supabase: &SupabaseClient, title: &str, source: &str, user_id: &str) -> Result<String> {
    let body = json!({
        "title": title,
        "source": source,
        "status": "queued",
        "user_id": user_id,
        "is_public": false
    });
    let rows = supabase.from("experiments").insert(body).select_returning("id").returns::<IdRow>().execute().await;
    let row = rows.map_err(|error| error.to_string())?.into_iter().next().ok_or("experiment insert returned no row".to_string())?;
    Ok(format!("queued id={}", row.id))
}

pub async fn validate_experiment(supabase: &SupabaseClient, source: &str) -> Result<String> {
    let body = json!({"source": source, "status": "working"});
    let rows = supabase.from("validation_jobs").insert(body).select_returning("id").returns::<IdRow>().execute().await;
    let row = rows.map_err(|error| error.to_string())?.into_iter().next().ok_or("validation insert returned no row".to_string())?;
    let validation_id = row.id;

    for _ in 0..VALIDATION_TIMEOUT_SEC {
        sleep(VALIDATION_POLL).await;
        let rows = supabase.from("validation_jobs").select("source, status, result_message").eq("id", validation_id).limit(1).returns::<ValidationRow>().execute().await;
        let row = rows.map_err(|error| error.to_string())?.into_iter().next().ok_or("validation job disappeared".to_string())?;
        match row.status.as_str() {
            "completed_valid" => return Ok(format!("valid validation_id={validation_id}")),
            "completed_invalid" => return Ok(format!("invalid: {}", row.result_message.unwrap_or_default())),
            "errored" => return Err(format!("validation job errored: {}", row.result_message.unwrap_or_default())),
            _ => continue
        }
    }

    Err(format!("validation job id={validation_id} did not complete within 60s"))
}

pub async fn queue_validated(supabase: &SupabaseClient, title: &str, validation_id: i64, user_id: &str) -> Result<String> {
    let rows = supabase.from("validation_jobs").select("source, status, result_message").eq("id", validation_id).limit(1).returns::<ValidationRow>().execute().await;
    let mut rows = rows.map_err(|error| error.to_string())?;
    let Some(row) = rows.pop() else {
        return Err(format!("validation job id={validation_id} not found"));
    };
    if row.status != "completed_valid" {
        let message = row.result_message.map_or("None".to_string(), |value| value);
        return Err(format!("validation job id={validation_id} is {}: {message}", row.status));
    }
    let source = row.source.ok_or("valid validation job is missing source".to_string())?;
    queue_experiment(supabase, title, &source, user_id).await
}

pub async fn list_experiments(supabase: &SupabaseClient, offset: i64, user_id: &str) -> Result<String> {
    if offset < 0 {
        return Err("offset must be >= 0".to_string());
    }
    let access_filter = format!("is_public.eq.true,user_id.eq.{user_id}");
    let unsigned_offset = offset as u64;
    let end = unsigned_offset.saturating_add(49);
    let rows = supabase.from("experiments").select("id, last_updated, title, status").or(&access_filter).order("last_updated", false).range(unsigned_offset, end).returns::<ExperimentListRow>().execute().await;
    let rows = rows.map_err(|error| error.to_string())?;
    let mut lines = vec![format!("[EXPERIMENTS] {} experiment(s)", rows.len())];
    for row in rows {
        lines.push(format!("id={} title={} status={}", row.id, row.title, row.status));
    }
    Ok(lines.join("\n"))
}

pub async fn status(supabase: &SupabaseClient, experiment_id: i64, user_id: &str) -> Result<String> {
    let row = accessible_row::<ExperimentStatusRow>(supabase, experiment_id, "id, status", user_id).await?;
    Ok(format!("status for experiment id={}: {}", row.id, row.status))
}

pub async fn experiment_source(supabase: &SupabaseClient, experiment_id: i64, user_id: &str) -> Result<String> {
    let row = accessible_row::<ExperimentSourceRow>(supabase, experiment_id, "source", user_id).await?;
    Ok(row.source)
}

pub async fn experiment_summary(supabase: &SupabaseClient, experiment_id: i64, user_id: &str) -> Result<String> {
    let row = accessible_row::<ExperimentSummaryRow>(supabase, experiment_id, "id, title, status, experiment", user_id).await?;
    let mut lines = vec![format!("id: {}", row.id), format!("title: {}", row.title), format!("status: {}", row.status), "experiment:".to_string()];
    for key in ["symbol", "cv_folds", "fold_size", "val_size", "test_size", "start_timestamp", "end_timestamp"] {
        lines.push(format!("{key}: {}", format_raw_value(&row.experiment[key])));
    }
    let strategy = &row.experiment["strategy"];
    lines.push(format!("strategy_type: {}", strategy["base_net"]["type"].as_str().unwrap_or_default()));
    lines.push(format!("feature_count: {}", strategy["feats"].as_array().map_or(0, Vec::len)));
    Ok(lines.join("\n"))
}

pub async fn results_summary(supabase: &SupabaseClient, experiment_id: i64, user_id: &str) -> Result<String> {
    let row = accessible_row::<ResultsSummaryRow>(supabase, experiment_id, "id, title, status, results", user_id).await?;
    let mut lines = vec![format!("id: {}", row.id), format!("title: {}", row.title), format!("status: {}", row.status)];
    let Some(results) = row.results else {
        lines.push("results: null".to_string());
        return Ok(lines.join("\n"));
    };
    if let Some(error) = results.as_object() {
        let internal = error["is_internal"].as_bool().unwrap_or(false);
        let message = if internal { "internal error" } else { error["error"].as_str().unwrap_or_default() };
        lines.push(format!("error: {message}"));
        return Ok(lines.join("\n"));
    }
    let folds = results.as_array().ok_or("results must be an array or object".to_string())?;
    lines.push(format!("# of folds: {}", folds.len()));
    for (i, fold) in folds.iter().enumerate() {
        lines.push(format!("[FOLD {}]", i + 1));
        lines.push(format!("train window: {} -> {}", format_raw_value(&fold["train_start_timestamp"]), format_raw_value(&fold["train_end_timestamp"])));
        lines.push(format!("val window: {} -> {}", format_raw_value(&fold["val_start_timestamp"]), format_raw_value(&fold["val_end_timestamp"])));
        lines.push(format!("test window: {} -> {}", format_raw_value(&fold["test_start_timestamp"]), format_raw_value(&fold["test_end_timestamp"])));
        for split in ["train", "val", "test"] {
            let split_results = &fold[format!("{split}_results")];
            lines.push(format!("{split} is_invalid: {}", format_raw_value(&split_results["is_invalid"])));
            lines.push(format!("{split} # of bars backtested: {}", format_raw_value(&split_results["n_bars"])));
            let metrics = split_results["metrics"].as_object().ok_or("metrics must be an object".to_string())?;
            let mut metric_names = metrics.keys().collect::<Vec<_>>();
            metric_names.sort();
            for metric in metric_names {
                lines.push(format!("{split} metric.{metric}: {}", format_raw_value(&metrics[metric])));
            }
        }
    }
    Ok(lines.join("\n"))
}

pub async fn experiment_paths(supabase: &SupabaseClient, experiment_id: i64, select: &[String], user_id: &str) -> Result<String> {
    let columns = "id, last_updated, title, status, experiment, results";
    let row = accessible_row::<ExperimentPathsRow>(supabase, experiment_id, columns, user_id).await?;
    let object = to_value(row).map_err(|error| error.to_string())?;
    let mut lines = vec![format!("[QUERY] {} path(s)", select.len())];
    for path in select {
        lines.push(format!("[RESULTS] {path}"));
        match resolve_path(&object, path) {
            Ok(value) => lines.push(format!("{} ({experiment_id})", format_value(&value))),
            Err(_) => lines.push("skipped".to_string())
        }
    }
    Ok(format!("{}\n", lines.join("\n")))
}

pub async fn convert(supabase: &SupabaseClient, experiment_id: i64, fold_idx: i64, platform: &str, user_id: &str) -> Result<String> {
    if platform != "pinescript" {
        return Err(format!("unsupported platform: {platform}"));
    }
    let experiment = accessible_row::<ExperimentStatusRow>(supabase, experiment_id, "id, status", user_id).await?;
    if experiment.status != "completed" {
        return Err(format!("experiment id={experiment_id} is {}, not completed", experiment.status));
    }
    let body = json!({"experiment_id": experiment_id, "fold_idx": fold_idx, "status": "working"});
    let rows = supabase.from("convert_jobs").insert(body).select_returning("id").returns::<IdRow>().execute().await;
    let row = rows.map_err(|error| error.to_string())?.into_iter().next().ok_or("convert insert returned no row".to_string())?;
    let job_id = row.id;

    for _ in (0..PINESCRIPT_TIMEOUT_SEC).step_by(PINESCRIPT_POLL.as_secs() as usize) {
        sleep(PINESCRIPT_POLL).await;
        let rows = supabase.from("convert_jobs").select("status, pinescript, error_message").eq("id", job_id).limit(1).returns::<ConvertRow>().execute().await;
        let row = rows.map_err(|error| error.to_string())?.into_iter().next().ok_or("pinescript job disappeared".to_string())?;
        match row.status.as_str() {
            "completed" => return row.pinescript.ok_or("completed pinescript job has no source".to_string()),
            "errored" => return Err(format!("pinescript job errored: {}", row.error_message.unwrap_or_default())),
            _ => continue
        }
    }
    Err(format!("pinescript job id={job_id} did not complete within 120s"))
}

pub async fn delete_experiment(supabase: &SupabaseClient, experiment_id: i64, user_id: &str) -> Result<String> {
    require_owned_experiment(supabase, experiment_id, user_id).await?;
    let deleted = supabase.from("experiments").delete().eq("user_id", user_id).eq("id", experiment_id).execute().await;
    deleted.map_err(|error| error.to_string())?;
    Ok(format!("deleted experiment id={experiment_id}"))
}
