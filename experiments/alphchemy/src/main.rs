use alphchemy::experiment::experiment::run_experiment_json;
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

fn without_legacy_title(mut experiment_json: Value) -> Value {
    if let Value::Object(fields) = &mut experiment_json {
        fields.remove("title");
    }

    experiment_json
}

fn write_experiment_entry<W: Write>(
    writer: &mut W,
    experiment_json: Value,
    data: &HashMap<String, Vec<f64>>
) -> Result<(), Box<dyn std::error::Error>> {
    let experiment_json = without_legacy_title(experiment_json);
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
    data: &HashMap<String, Vec<f64>>
) -> Result<BatchStats, Box<dyn std::error::Error>> {
    let mut stats = BatchStats::default();

    for (line_index, line_result) in reader.lines().enumerate() {
        let line_number = line_index + 1;
        let line = line_result?;
        let trimmed = line.trim();

        if trimmed.is_empty() {
            continue;
        }

        let parsed = serde_json::from_str::<Value>(trimmed);
        let experiment_json = match parsed {
            Ok(json) => json,
            Err(error) => {
                eprintln!("skipping invalid generated line {line_number}: {error}");
                stats.skipped_count += 1;
                continue;
            }
        };

        println!("running generated line {line_number}");

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
    data: &HashMap<String, Vec<f64>>
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_without_legacy_title_removes_title() {
        let experiment_json = json!({
            "title": "legacy",
            "val_size": 0.2
        });

        let sanitized = without_legacy_title(experiment_json);

        assert!(sanitized.get("title").is_none());
        assert_eq!(sanitized["val_size"], 0.2);
    }
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
