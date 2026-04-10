use alphchemy::experiment::experiment::run_experiment_json;
use ndarray::Array1;
use csv::{Reader, StringRecord};
use serde_json::Value;
use std::collections::HashMap;
use std::fs::{self, File, OpenOptions};
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::path::{Path, PathBuf};

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

fn read_ohlc_data(path: &Path) -> Result<HashMap<String, Array1<f64>>, String> {
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

#[derive(Debug, Default, PartialEq, Eq)]
struct BatchStats {
    written_count: usize,
    skipped_count: usize
}

fn repo_data_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../data")
}

fn btc_data_path() -> PathBuf {
    repo_data_dir().join("btc_data.csv")
}

fn generated_path() -> PathBuf {
    repo_data_dir().join("generated.jsonl")
}

fn experiments_path() -> PathBuf {
    repo_data_dir().join("experiments.jsonl")
}

fn experiment_title(experiment_json: &Value) -> &str {
    let title_json = experiment_json.get("title");
    let maybe_title = title_json.and_then(|value| value.as_str());
    maybe_title.unwrap_or("unknown")
}

fn write_experiment_entry<W: Write>(
    writer: &mut W,
    experiment_json: Value,
    data: &HashMap<String, Array1<f64>>
) -> Result<(), Box<dyn std::error::Error>> {
    let results = run_experiment_json(&experiment_json, data);

    let entry_json = serde_json::json!({
        "experiment": experiment_json,
        "results": results
    });

    serde_json::to_writer(&mut *writer, &entry_json)?;
    writer.write_all(b"\n")?;

    Ok(())
}

fn write_experiment_results<R: BufRead, W: Write>(
    reader: R,
    mut writer: W,
    data: &HashMap<String, Array1<f64>>
) -> Result<BatchStats, Box<dyn std::error::Error>> {
    let mut stats = BatchStats::default();

    for (line_index, line_result) in reader.lines().enumerate() {
        let line = line_result?;
        let trimmed = line.trim();

        if trimmed.is_empty() {
            continue;
        }

        let parsed = serde_json::from_str::<Value>(trimmed);
        let experiment_json = match parsed {
            Ok(json) => json,
            Err(error) => {
                let line_number = line_index + 1;
                eprintln!("skipping invalid generated line {line_number}: {error}");
                stats.skipped_count += 1;
                continue;
            }
        };

        let title = experiment_title(&experiment_json);
        println!("running {title}");

        write_experiment_entry(&mut writer, experiment_json, data)?;
        writer.flush()?;
        stats.written_count += 1;
    }

    writer.flush()?;

    Ok(stats)
}

fn process_generated_file(
    input_path: &Path,
    output_path: &Path,
    data: &HashMap<String, Array1<f64>>
) -> Result<BatchStats, Box<dyn std::error::Error>> {
    let input_file = File::open(input_path)?;
    let input_reader = BufReader::new(input_file);

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let output_file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(output_path)?;
    let output_writer = BufWriter::new(output_file);

    write_experiment_results(input_reader, output_writer, data)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let data_path = btc_data_path();
    let ohlc_result = read_ohlc_data(&data_path);
    let data = ohlc_result
        .map_err(|err| -> Box<dyn std::error::Error> { err.into() })?;

    let input_path = generated_path();
    let output_path = experiments_path();
    let stats = process_generated_file(&input_path, &output_path, &data)?;

    println!("processed {} experiments", stats.written_count);

    if stats.skipped_count > 0 {
        println!("skipped {} invalid generated lines", stats.skipped_count);
    }

    println!("wrote results to {}", output_path.display());

    Ok(())
}
