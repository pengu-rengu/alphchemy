use alphchemy_analysis::format::{format_query_results, format_value};
use alphchemy_analysis::path::resolve_path;
use alphchemy_analysis::query::{Query, QueryResults, Visibility};
use serde_json::{Value, json};

fn public_experiment(mut experiment: Value) -> Value {
    experiment["is_public"] = Value::Bool(true);
    experiment["user_id"] = Value::Null;
    experiment
}

fn run_query(text: &str, experiments: Vec<Value>) -> Query {
    let experiments = experiments.into_iter().map(public_experiment).collect();
    let mut query = Query::new(text);
    query.run(experiments, "owner").unwrap();
    query
}

#[test]
fn path_resolves_nested_and_self_aggregates() {
    let object = json!({
        "results": [
            {"test_results": {"equity_curve": [1.0, 3.0]}},
            {"test_results": {"equity_curve": [10.0, 14.0]}},
            {"train_results": {"equity_curve": [100.0]}}
        ],
        "curve": [2.0, 4.0, 6.0]
    });

    let nested = resolve_path(&object, "results.mean:test_results.std:equity_curve.self").unwrap();
    assert_eq!(nested, json!(1.5));
    assert_eq!(resolve_path(&object, "curve.mean:self").unwrap(), json!(4.0));
    assert_eq!(resolve_path(&object, "curve.min:self").unwrap(), json!(2.0));
    assert_eq!(resolve_path(&object, "curve.max:self").unwrap(), json!(6.0));
    assert_eq!(resolve_path(&object, "curve.len:self").unwrap(), json!(3.0));
}

#[test]
fn path_aggregates_bools_and_skips_missing_keys() {
    let object = json!({
        "results": [
            {"test_results": {"is_invalid": false}},
            {"test_results": {"is_invalid": true}},
            {"test_results": {"is_invalid": true}},
            {"train_results": {"is_invalid": true}}
        ]
    });

    let mean = resolve_path(&object, "results.mean:test_results.is_invalid").unwrap();
    let std = resolve_path(&object, "results.std:test_results.is_invalid").unwrap();
    assert!((mean.as_f64().unwrap() - 2.0 / 3.0).abs() < 1e-12);
    assert!((std.as_f64().unwrap() - 0.4714045207910317).abs() < 1e-12);
    assert_eq!(resolve_path(&object, "results.min:test_results.is_invalid").unwrap(), json!(0.0));
    assert_eq!(resolve_path(&object, "results.max:test_results.is_invalid").unwrap(), json!(1.0));
}

#[test]
fn path_errors_preserve_context() {
    let old_syntax = resolve_path(&json!({"results": []}), "results.mean.test_results.metrics.sharpe").unwrap_err();
    assert!(old_syntax.to_string().contains("colon syntax"));
    let self_error = resolve_path(&json!({"metrics": {"sharpe": 1.0}}), "metrics.std:sharpe.self").unwrap_err();
    assert!(self_error.to_string().contains(".self requires a list target"));
    let target_error = resolve_path(&json!({"results": {}}), "results.mean:test_results.metrics.sharpe").unwrap_err();
    assert!(target_error.to_string().contains("results"));
    let numeric_error = resolve_path(&json!({"results": [{"test_results": {"metrics": {"sharpe": "bad"}}}]}), "results.mean:test_results.metrics.sharpe").unwrap_err();
    assert!(numeric_error.to_string().contains("test_results.metrics.sharpe"));
}

#[test]
fn query_parser_preserves_selection_visibility_and_sort_contract() {
    let mut query = Query::new("visibility: private\nselect:\n  title\n  15+50(experiment.score)\n  mean(results.mean:test_results.metrics.sharpe)\n  count\nsort_desc: experiment.score");
    query.parse().unwrap();

    assert_eq!(query.visibility, Visibility::Private);
    assert_eq!(query.select[0].limit, Some(25));
    assert_eq!(query.select[0].offset, 0);
    assert_eq!(query.select[1].limit, Some(15));
    assert_eq!(query.select[1].offset, 50);
    assert_eq!(query.select[2].limit, None);
    assert_eq!(query.select[2].aggregate.as_deref(), Some("mean"));
    assert_eq!(query.select[3].path, "");
    assert_eq!(query.select[3].limit, None);
    assert_eq!(query.select[3].aggregate.as_deref(), Some("count"));
    assert_eq!(query.sort.as_ref().unwrap().path, "experiment.score");
    assert!(query.sort.as_ref().unwrap().descending);
}

#[test]
fn query_parser_rejects_protected_paths_and_invalid_wrappers() {
    for text in ["select:\n id", "select:\n title\nfilters:\n id >= 1", "select:\n title\nsort_desc: user_id"] {
        let error = Query::new(text).parse().unwrap_err();
        assert!(error.contains("cannot be"));
    }
    for selection in ["0(title)", "26(title)"] {
        let text = format!("select:\n {selection}");
        let error = Query::new(text).parse().unwrap_err();
        assert!(error.contains("limit must be between 1 and 25"));
    }
    for selection in ["10(mean(title))"] {
        let text = format!("select:\n {selection}");
        let error = Query::new(text).parse().unwrap_err();
        assert!(error.contains("cannot be nested"));
    }
}

#[test]
fn query_filters_timestamps_in_iso_display_and_offset_forms() {
    let experiments = vec![
        json!({"id": 1, "last_updated": "2024-05-31T23:00:00", "title": "before"}),
        json!({"id": 2, "last_updated": "2024-06-01T03:30:00+03:30", "title": "inside"}),
        json!({"id": 3, "last_updated": "Jul 1 2024 00:00", "title": "after"}),
        json!({"id": 4, "last_updated": "not a date", "title": "invalid"})
    ];
    let text = "select:\n title\nfilters:\n last_updated >= Jun 1 2024 00:00\n last_updated < 2024-07-01T00:00:00Z";
    let query = run_query(text, experiments);
    assert_eq!(query.results.unwrap()[0].values, vec![json!("inside")]);
}

#[test]
fn query_filters_timestamps_without_seconds() {
    let experiments = vec![
        json!({"id": 1, "last_updated": "2026-07-19T23:59:59Z", "title": "before"}),
        json!({"id": 2, "last_updated": "2026-07-20T00:00:00Z", "title": "inside"}),
        json!({"id": 3, "last_updated": "2026-08-20T00:00:00Z", "title": "after"})
    ];
    let text = "select:\n title\nfilters:\n last_updated >= 2026-07-20T00:00\n last_updated < 2026-08-20";
    let query = run_query(text, experiments);
    assert_eq!(query.results.unwrap()[0].values, vec![json!("inside")]);
}

#[test]
fn query_applies_visibility_filters_then_independent_windows() {
    let experiments = vec![
        json!({"id": 1, "title": "other", "experiment": {"score": 4.0}, "is_public": false, "user_id": "other"}),
        json!({"id": 2, "title": "newest", "experiment": {"score": 3.0}, "is_public": true, "user_id": null}),
        json!({"id": 3, "title": "middle", "experiment": {"score": 2.0}, "is_public": false, "user_id": "owner"}),
        json!({"id": 4, "title": "oldest", "experiment": {"score": 1.0}, "is_public": true, "user_id": null})
    ];
    let mut query = Query::new("select:\n 1(title)\n 2+1(experiment.score)\nfilters:\n experiment.score >= 1\nvisibility: all");
    query.run(experiments, "owner").unwrap();
    let results = query.results.unwrap();
    assert_eq!(results[0].values, vec![json!("newest")]);
    assert_eq!(results[0].ids, vec![2]);
    assert_eq!(results[1].values, vec![json!(2.0), json!(1.0)]);
    assert_eq!(results[1].ids, vec![3, 4]);
}

#[test]
fn visibility_modes_match_public_and_owned_private_rows() {
    let experiments = vec![
        json!({"id": 1, "title": "public", "is_public": true, "user_id": null}),
        json!({"id": 2, "title": "owned private", "is_public": false, "user_id": "owner"}),
        json!({"id": 3, "title": "other private", "is_public": false, "user_id": "other"})
    ];
    let cases = [
        ("all", vec![json!("public"), json!("owned private")]),
        ("public", vec![json!("public")]),
        ("private", vec![json!("owned private")])
    ];
    for (visibility, expected) in cases {
        let text = format!("select:\n title\nvisibility: {visibility}");
        let mut query = Query::new(text);
        query.run(experiments.clone(), "owner").unwrap();
        assert_eq!(query.results.unwrap()[0].values, expected);
    }
}

#[test]
fn query_aggregates_all_matches_and_preserves_extrema_ids() {
    let experiments = (0..30).map(|i| json!({"id": i, "experiment": {"score": (i % 3 + 1) as f64}})).collect::<Vec<_>>();
    let cases = [("mean", 2.0, vec![]), ("min", 1.0, vec![0]), ("max", 3.0, vec![2])];
    for (aggregate, expected, expected_ids) in cases {
        let text = format!("select:\n {aggregate}(experiment.score)");
        let query = run_query(&text, experiments.clone());
        let result = &query.results.unwrap()[0];
        assert_eq!(result.values, vec![json!(expected)]);
        assert_eq!(result.ids, expected_ids);
    }
    let query = run_query("select:\n std(experiment.score)", experiments);
    let std = query.results.unwrap()[0].values[0].as_f64().unwrap();
    assert!((std - 0.816496580927726).abs() < 1e-12);
}

#[test]
fn query_counts_post_sort_experiments_and_formats_an_integer() {
    let experiments = vec![
        json!({"id": 1, "title": "kept", "experiment": {"score": 4.0, "rank": 2.0}}),
        json!({"id": 2, "title": "missing sort", "experiment": {"score": 3.0}}),
        json!({"id": 3, "title": "filtered", "experiment": {"score": 2.0, "rank": 1.0}})
    ];
    let text = "select:\n count\n title\nfilters:\n experiment.score >= 3\nsort_asc: experiment.rank";
    let query = run_query(text, experiments);
    let output = format_query_results(&query);
    let results = query.results.unwrap();
    assert_eq!(results[0].values, vec![json!(1)]);
    assert!(results[0].ids.is_empty());
    assert_eq!(results[0].skipped, 0);
    assert_eq!(results[1].values, vec![json!("kept")]);
    assert_eq!(results[1].skipped, 1);
    assert!(output.contains("[RESULTS] count\n1"));
    assert!(!output.contains("[RESULTS] count\n1.00"));
}

#[test]
fn query_count_returns_zero_for_no_matches() {
    let experiments = vec![json!({"id": 1, "experiment": {"score": 1.0}})];
    let query = run_query("select:\n count\nfilters:\n experiment.score > 1", experiments);
    let result = &query.results.unwrap()[0];
    assert_eq!(result.values, vec![json!(0)]);
    assert!(result.ids.is_empty());
    assert_eq!(result.skipped, 0);
}

#[test]
fn query_aggregate_coerces_bools_and_counts_missing_values() {
    let experiments = vec![
        json!({"id": 1, "experiment": {"enabled": false}}),
        json!({"id": 2, "experiment": {"enabled": true}}),
        json!({"id": 3, "experiment": {}})
    ];
    let query = run_query("select:\n mean(experiment.enabled)", experiments);
    let result = &query.results.unwrap()[0];
    assert_eq!(result.values, vec![json!(0.5)]);
    assert!(result.ids.is_empty());
    assert_eq!(result.skipped, 1);
}

#[test]
fn query_sorts_numbers_aggregates_and_timestamps_before_offset() {
    let numbers = vec![
        json!({"id": 1, "title": "tie new", "experiment": {"score": 2}}),
        json!({"id": 2, "title": "high", "experiment": {"score": 3}}),
        json!({"id": 3, "title": "tie old", "experiment": {"score": 2}}),
        json!({"id": 4, "title": "low", "experiment": {"score": 1}})
    ];
    let asc = run_query("select:\n 25+1(title)\nsort_asc: experiment.score", numbers.clone());
    assert_eq!(asc.results.unwrap()[0].ids, vec![1, 3, 2]);
    let desc = run_query("select:\n 25+1(title)\nsort_desc: experiment.score", numbers);
    assert_eq!(desc.results.unwrap()[0].ids, vec![1, 3, 4]);

    let timestamps = vec![
        json!({"id": 1, "last_updated": "2024-06-01T00:00:00Z"}),
        json!({"id": 2, "last_updated": "2024-06-01T02:00:00+03:00"}),
        json!({"id": 3, "last_updated": "May 31 2024 22:00"})
    ];
    let sorted = run_query("select:\n last_updated\nsort_asc: last_updated", timestamps);
    assert_eq!(sorted.results.unwrap()[0].ids, vec![3, 2, 1]);

    let aggregate_rows = vec![
        json!({"id": 1, "results": [{"test_results": {"metrics": {"sharpe": 1.0}}}]}),
        json!({"id": 2, "results": [{"test_results": {"metrics": {"sharpe": 3.0}}}]}),
        json!({"id": 3, "results": [{"test_results": {"metrics": {"sharpe": 2.0}}}]})
    ];
    let path = "results.mean:test_results.metrics.sharpe";
    let text = format!("select:\n {path}\nsort_desc: {path}");
    let sorted = run_query(&text, aggregate_rows);
    assert_eq!(sorted.results.unwrap()[0].ids, vec![2, 3, 1]);
}

#[test]
fn query_sort_counts_missing_and_rejects_mixed_types() {
    let experiments = vec![
        json!({"id": 1, "experiment": {"score": 2.0}}),
        json!({"id": 2, "experiment": {}}),
        json!({"id": 3, "experiment": {"score": 1.0}})
    ];
    let query = run_query("select:\n experiment.score\nsort_asc: experiment.score", experiments);
    let result = &query.results.unwrap()[0];
    assert_eq!(result.ids, vec![3, 1]);
    assert_eq!(result.skipped, 1);

    let mixed = vec![
        public_experiment(json!({"id": 1, "experiment": {"value": 1.0}})),
        public_experiment(json!({"id": 2, "experiment": {"value": "2024-06-01T00:00:00Z"}}))
    ];
    let mut query = Query::new("select:\n experiment.value\nsort_asc: experiment.value");
    let error = query.run(mixed, "owner").unwrap_err();
    assert!(error.to_string().contains("cannot mix numbers and timestamps"));
}

#[test]
fn formatting_matches_query_text_contract() {
    assert_eq!(format_value(&json!("2026-01-02T12:00:00")), "Jan 2 2026 12:00");
    assert_eq!(format_value(&json!("Copy of asdfasdf")), "Copy of asdfasdf");
    assert_eq!(format_value(&json!(1.2)), "1.20");
    assert_eq!(format_value(&json!(0.0012)), "0.00120");
    assert_eq!(format_value(&json!(0.0000123)), "0.0000123");
    assert_eq!(format_value(&json!(12345.6)), "12346");
    let mut query = Query::new("select:\n title");
    query.results = Some(vec![QueryResults {
        path: "title".to_string(),
        values: vec![json!("alpha"), json!("beta")],
        ids: vec![12, 13],
        skipped: 1
    }]);
    let output = format_query_results(&query);
    assert!(output.contains("[QUERY] 1 path(s)"));
    assert!(output.contains("alpha (12), beta (13)"));
    assert!(output.contains("skipped: 1"));
}
