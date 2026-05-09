use alphchemy::experiment::experiment::run_experiment_json;
use csv::{Reader, StringRecord};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::Duration;
use std::env;
use tokio::time::sleep;
use supabase_rs::SupabaseClient;

const POLL_INTERVAL: Duration = Duration::from_secs(2);

fn find_col_idx(headers: &StringRecord, col_name: &str) -> Result<usize, String> {
    let maybe_pos = headers.iter().position(|header| header == col_name);
    maybe_pos.ok_or_else(|| format!("missing column: {col_name}"))
}

fn parse_col(record: &StringRecord, idx: usize, col_name: &str) -> Result<f64, String> {
    let maybe_field = record.get(idx);
    let field = maybe_field.ok_or_else(|| format!("missing {col_name} value"))?;

    let value = field.parse::<f64>();
    value.map_err(|error| format!("invalid {col_name} value '{field}': {error}"))
}

fn read_ohlc_data(path: &Path) -> Result<HashMap<String, Vec<f64>>, String> {
    let reader = Reader::from_path(path);
    let display = path.display();
    let mut reader = reader.map_err(|error| format!("failed to open {display}: {error}"))?;

    let mut open = Vec::new();
    let mut high = Vec::new();
    let mut low = Vec::new();
    let mut close = Vec::new();

    let headers = reader.headers().map_err(|error| format!("failed to read headers: {error}"))?;
    let open_idx = find_col_idx(headers, "open")?;
    let high_idx = find_col_idx(headers, "high")?;
    let low_idx = find_col_idx(headers, "low")?;
    let close_idx = find_col_idx(headers, "close")?;

    for result in reader.records() {
        let record = result.map_err(|error| format!("failed to read row: {error}"))?;

        let open_val = parse_col(&record, open_idx, "open")?;
        open.push(open_val);

        let high_val = parse_col(&record, high_idx, "high")?;
        high.push(high_val);

        let low_val = parse_col(&record, low_idx, "low")?;
        low.push(low_val);

        let close_val = parse_col(&record, close_idx, "close")?;
        close.push(close_val);
    }

    let mut data = HashMap::new();
    data.insert("open".to_string(), open);
    data.insert("high".to_string(), high);
    data.insert("low".to_string(), low);
    data.insert("close".to_string(), close);

    Ok(data)
}

fn btc_data_path() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../data/btc_data.csv")
}

fn terminal_status(result: &Value) -> &'static str {
    let has_error = match result {
        Value::Object(fields) => fields.contains_key("error"),
        _ => false
    };

    if has_error {
        "errored"
    } else {
        "completed"
    }
}

async fn fetch_next(client: &SupabaseClient) -> Result<Option<Value>, String> {
    let base = client.select("experiments");
    let filtered = base.eq("status", "queued");
    let sorted = filtered.order("created_at", true);
    let rows = sorted.limit(1).execute().await?;
    Ok(rows.into_iter().next())
}

async fn process_one(client: &SupabaseClient, data: &HashMap<String, Vec<f64>>) -> Result<bool, String> {
    let maybe_row = fetch_next(client).await?;
    let row = match maybe_row {
        Some(value) => value,
        None => return Ok(false)
    };

    let maybe_id = row.get("id");
    let id_value = maybe_id.ok_or_else(|| "missing id".to_string())?;
    let id_number = id_value.as_i64().ok_or_else(|| "id is not i64".to_string())?;
    let id = id_number.to_string();

    let experiment_value = row.get("experiment").cloned();
    let experiment = experiment_value.ok_or_else(|| "missing experiment".to_string())?;
    
    client.update("experiments", &id, json!({"status": "running"})).await?;
    println!("claimed id={id}");

    let results = run_experiment_json(&experiment, data);
    let status = terminal_status(&results);
    client.update("experiments", &id, json!({
        "status": status,
        "results": results
    })).await?;
    println!("{status} id={id}");

    Ok(true)
}

#[tokio::main]
async fn main() {
    let data_path = btc_data_path();
    let data = read_ohlc_data(&data_path).unwrap();

    let url = env::var("SUPABASE_URL").unwrap();
    let key = env::var("SUPABASE_KEY").unwrap();
    let client = SupabaseClient::new(url, key).unwrap();

    loop {
        let result = process_one(&client, &data).await;
        let next  = match result {
            Ok(value) => value,
            Err(error) => {
                println!("{}", error);
                false
            }
        };
        if next {
            continue;
        }

        println!("idle");
        sleep(POLL_INTERVAL).await;
    }
}
