use redis::Commands;

use alphchemy::experiment::experiment::run_experiment_json;
use std::collections::HashMap;
use ndarray::Array1;
use csv::{Reader, StringRecord};
use redis::Client;

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


pub fn read_ohlc_data(path: &str) -> Result<HashMap<String, Array1<f64>>, String> {
    let reader = Reader::from_path(path);
    let mut reader = reader.map_err(|error| format!("failed to open {path}: {error}"))?;

    let mut open = Vec::new();
    let mut high = Vec::new();
    let mut low = Vec::new();
    let mut close= Vec::new();

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
    let open_array = Array1::from_vec(open);
    data.insert("open".to_string(), open_array);
    let high_array = Array1::from_vec(high);
    data.insert("high".to_string(), high_array);
    let low_array = Array1::from_vec(low);
    data.insert("low".to_string(), low_array);
    let close_array = Array1::from_vec(close);
    data.insert("close".to_string(), close_array);

    Ok(data)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let data_path = "../../data/btc_data.csv";
    let ohlc_result = read_ohlc_data(data_path);
    let data = ohlc_result
        .map_err(|err| -> Box<dyn std::error::Error> { err.into() })?;

    let mut conn = Client::open("redis://localhost:6379")?.get_connection()?;

    loop {
        println!("waiting");

        let pop_result = conn.brpop::<&str, (String, String)>("experiments", 0.0)?;
        let experiment_data = pop_result.1;

        let experiment_json: serde_json::Value = match serde_json::from_str(&experiment_data) {
            Ok(json) => json,
            Err(err) => {
                println!("Error parsing experiment data: {err}");
                continue;
            }
        };

        let title_json = experiment_json.get("title");
        let maybe_title = title_json.and_then(|val| val.as_str());
        let title = maybe_title.unwrap_or("unknown");
        println!("running {title}");

        let results = run_experiment_json(&experiment_json, &data);

        let entry_json = serde_json::json!({
            "experiment": experiment_json,
            "results": results
        });

        let entry_str = serde_json::to_string(&entry_json)?;

        let push_result: Result<(), _> = conn.lpush("results", &entry_str);
        if let Err(err) = push_result {
            println!("Internal error occurred when processing JSON");
            println!("{err}");
        }
    }
}
