use std::fs;
use std::path::Path;

use serde_json::Value;

use alphchemy::parse::parse_experiment::parse_experiment;

// Parses the repo-root mock source seeds (mock_sources/), re-serializes each
// parsed experiment, and checks it round-trips to the canonical experiment column
// shape in mock_experiments.json. Guarantees the source format, the Rust parser,
// and the Rust serializer all agree. The same seeds are used by queue_mock.py.
#[test]
fn fixtures_round_trip_to_canonical_json() {
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let fixtures_dir = Path::new(manifest_dir).join("..").join("..").join("mock_sources");
    let mock_path = Path::new(manifest_dir).join("..").join("..").join("mock_experiments.json");
    let mock_text = fs::read_to_string(&mock_path).expect("mock_experiments.json should exist");
    let mock: Vec<Value> = serde_json::from_str(&mock_text).expect("mock should parse");

    assert_eq!(mock.len(), 5);

    for index in 0..5 {
        let path = fixtures_dir.join(format!("mock_{index}.txt"));
        let source = fs::read_to_string(&path).expect("fixture should exist");
        let result = parse_experiment(&source);
        assert!(result.is_ok(), "fixture mock_{index} failed to parse: {:?}", result.err());

        let produced = normalize(result.unwrap().to_json());
        let expected = normalize(mock[index].clone());
        assert_eq!(produced, expected, "fixture mock_{index} did not round-trip");
    }
}

// Strip trailing timestamp "Z" so ISO (Rust) and ISO+Z (mock) compare equal.
fn normalize(value: Value) -> Value {
    match value {
        Value::String(text) => Value::String(text.trim_end_matches('Z').to_string()),
        Value::Array(items) => Value::Array(items.into_iter().map(normalize).collect()),
        Value::Object(map) => {
            let entries = map.into_iter().map(|(key, child)| (key, normalize(child)));
            Value::Object(entries.collect())
        }
        other => other
    }
}
