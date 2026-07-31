use alphchemy_utils::{field_array, field_f64, field_str, field_string, field_usize, get_field, parse_timestamp};
use serde_json::json;

#[test]
fn parses_supported_timestamp_formats() {
    let cases = [
        ("2024-06-01T03:30:00+03:30", "2024-06-01T00:00:00"),
        ("2024-06-01T00:00:00.123", "2024-06-01T00:00:00"),
        ("2024-06-01T00:00:00", "2024-06-01T00:00:00"),
        ("2024-06-01T00:00", "2024-06-01T00:00:00"),
        ("2024-06-01", "2024-06-01T00:00:00"),
        ("Jun 1 2024 00:00", "2024-06-01T00:00:00")
    ];

    for (text, expected) in cases {
        let parsed = parse_timestamp(text);
        assert_eq!(parsed.as_deref(), Ok(expected));
    }
}

#[test]
fn rejects_invalid_timestamp() {
    let parsed = parse_timestamp("sometime");
    assert_eq!(parsed, Err("invalid timestamp: sometime".to_string()));
}

#[test]
fn accesses_json_fields() {
    let json = json!({
        "array": [1, 2],
        "float": 1.5,
        "text": "value",
        "usize": 2
    });

    let raw = get_field(&json, "text");
    assert_eq!(raw, Ok(&json["text"]));

    let float = field_f64(&json, "float");
    assert_eq!(float, Ok(1.5));

    let usize_value = field_usize(&json, "usize");
    assert_eq!(usize_value, Ok(2));

    let text = field_str(&json, "text");
    assert_eq!(text, Ok("value"));

    let string = field_string(&json, "text");
    assert_eq!(string, Ok("value".to_string()));

    let array = field_array(&json, "array");
    let expected_array = json["array"].as_array();
    let expected_array = expected_array.unwrap();
    assert_eq!(array, Ok(expected_array));
}

#[test]
fn rejects_missing_and_invalid_json_fields() {
    let json = json!({
        "array": "invalid",
        "float": "invalid",
        "text": 1,
        "usize": "invalid"
    });

    let missing = get_field(&json, "missing");
    assert_eq!(missing, Err("missing missing".to_string()));

    let float = field_f64(&json, "float");
    assert_eq!(float, Err("float must be f64".to_string()));

    let usize_value = field_usize(&json, "usize");
    assert_eq!(usize_value, Err("usize must be u64".to_string()));

    let text = field_str(&json, "text");
    assert_eq!(text, Err("text must be string".to_string()));

    let string = field_string(&json, "text");
    assert_eq!(string, Err("text must be string".to_string()));

    let array = field_array(&json, "array");
    assert_eq!(array, Err("array must be array".to_string()));
}
