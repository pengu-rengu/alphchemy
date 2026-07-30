use std::sync::{Arc, Mutex};

#[allow(dead_code)]
#[path = "../src/main.rs"]
mod analysis_main;

use alphchemy_analysis::format::format_value;
use alphchemy_analysis::tools::data_tools::{avg_price, data_range};
use alphchemy_analysis::tools::benchmark_tools::{create_benchmark, delete_benchmark, disable_benchmark_mode, enable_benchmark_mode, list_benchmarks, view_benchmark};
use alphchemy_analysis::tools::experiment_tools::{convert, delete_experiment, experiment_paths, experiment_source, experiment_summary, list_experiments, queue_experiment, results_summary, status, validate_experiment};
use alphchemy_analysis::tools::notebook_tools::{create_notebook, update_notebook};
use alphchemy_analysis::tools::query_tools::{load_experiments, query_experiments};
use analysis_main::process_notebook;
use axum::serve;
use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::{Method, StatusCode};
use axum::response::Response;
use axum::routing::any;
use axum::Router;
use rust_supabase_sdk::SupabaseClient;
use serde_json::{Value, from_slice, from_str, json};
use tokio::fs::read_to_string;
use tokio::net::TcpListener;
use tokio::spawn;
use tokio::task::JoinHandle;

#[derive(Clone, Copy)]
struct ExperimentResponse {
    count: usize,
    error_offset: Option<usize>
}

#[derive(Clone)]
struct MockState {
    requests: Arc<Mutex<Vec<(Method, String, Value)>>>,
    experiment_response: Arc<Mutex<ExperimentResponse>>,
    worker_query: String,
    validation_status: String,
    convert_status: String,
    active_model: Option<String>
}

fn json_response(value: Value) -> Response {
    Response::builder().status(StatusCode::OK).header("content-type", "application/json").body(Body::from(value.to_string())).unwrap()
}

fn statement_timeout_response() -> Response {
    let error = json!({
        "code": "57014",
        "message": "canceling statement due to statement timeout",
        "details": null,
        "hint": null
    });
    let builder = Response::builder();
    let builder = builder.status(StatusCode::INTERNAL_SERVER_ERROR);
    let builder = builder.header("content-type", "application/json");
    let text = error.to_string();
    let body = Body::from(text);
    let response = builder.body(body);
    response.unwrap()
}

fn query_parameter(uri: &str, name: &str) -> usize {
    let parts = uri.split_once('?');
    let parts = parts.unwrap();
    for parameter in parts.1.split('&') {
        let Some((key, value)) = parameter.split_once('=') else {
            continue;
        };
        if key == name {
            let parsed = value.parse::<usize>();
            return parsed.unwrap();
        }
    }
    panic!("missing query parameter `{name}`")
}

fn experiment_row(index: usize) -> Value {
    let id = index as u64;
    let id = id + 1;
    json!({
        "id": id,
        "last_updated": "2026-07-01T00:00:00Z",
        "title": "Public experiment",
        "experiment": {"score": 2.0},
        "results": null,
        "status": "completed",
        "user_id": null,
        "is_public": true
    })
}

fn set_experiment_response(state: &MockState, count: usize, error_offset: Option<usize>) {
    let mut response = state.experiment_response.lock().unwrap();
    *response = ExperimentResponse {
        count,
        error_offset
    };
}

fn completed_experiment_requests(state: &MockState) -> Vec<String> {
    let requests = state.requests.lock().unwrap();
    let mut uris = Vec::new();
    for request in requests.iter() {
        let is_completed_query = request.1.contains("status=eq.completed");
        if request.0 == Method::GET && is_completed_query {
            uris.push(request.1.clone());
        }
    }
    uris
}

async fn postgrest(State(state): State<MockState>, request: Request) -> Response {
    let method = request.method().clone();
    let uri = request.uri().to_string();
    let bytes = to_bytes(request.into_body(), usize::MAX).await.unwrap();
    let body = if bytes.is_empty() { Value::Null } else { from_slice(&bytes).unwrap() };
    state.requests.lock().unwrap().push((method.clone(), uri.clone(), body));

    if uri.starts_with("/rest/v1/experiments") {
        if method == Method::POST {
            return json_response(json!([{"id": 9}]));
        }
        if method == Method::DELETE || method == Method::PATCH {
            return json_response(json!([]));
        }
        if uri.contains("select=id&") {
            return json_response(json!([{"id": 1}]));
        }
        if uri.contains("status=eq.completed") {
            let offset = query_parameter(&uri, "offset");
            let limit = query_parameter(&uri, "limit");
            let experiment_response = state.experiment_response.lock().unwrap();
            let experiment_response = *experiment_response;
            if experiment_response.error_offset == Some(offset) {
                return statement_timeout_response();
            }
            let end = offset + limit;
            let end = end.min(experiment_response.count);
            let mut experiments = Vec::new();
            for index in offset..end {
                experiments.push(experiment_row(index));
            }
            return json_response(Value::Array(experiments));
        }
        return json_response(json!([{
            "id": 1,
            "last_updated": "2026-07-01T00:00:00Z",
            "title": "Public experiment",
            "source": "cv_folds: 3",
            "experiment": {},
            "results": null,
            "status": "completed",
            "user_id": null,
            "is_public": true
        }]));
    }
    if uri.starts_with("/rest/v1/notebooks") {
        if method == Method::POST {
            return json_response(json!([{"id": 3}]));
        }
        if method == Method::PATCH || method == Method::DELETE {
            return json_response(json!([]));
        }
        if uri.contains("status=eq.working") {
            return json_response(json!([{
                "id": 7,
                "queries": [{"query": state.worker_query, "results": null}],
                "user_id": "owner"
            }]));
        }
        return json_response(json!([{
            "id": 7,
            "last_updated": "2026-07-01T00:00:00Z",
            "title": "Notebook",
            "queries": [{"query": "select:\n title", "results": null}],
            "notes": ["note"],
            "status": "idle",
            "error_message": null
        }]));
    }
    if uri.starts_with("/rest/v1/benchmarks") {
        if method == Method::POST {
            return json_response(json!([{"id": 5}]));
        }
        if method == Method::PATCH || method == Method::DELETE {
            return json_response(json!([]));
        }
        return json_response(json!([{
            "id": 5,
            "last_updated": "2026-07-01T00:00:00Z",
            "title": "Benchmark",
            "score_path": "results.mean:test_results.metrics.excess_sharpe",
            "cutoff": "2026-07-01T00:00:00Z",
            "data": {
                "claude-opus-5": {
                    "scores": [0.1, 0.2],
                    "experiment_ids": [1, 2]
                }
            },
            "active_model": state.active_model
        }]));
    }
    if uri.starts_with("/rest/v1/validation_jobs") {
        if method == Method::POST {
            return json_response(json!([{"id": 21}]));
        }
        let message = if state.validation_status == "completed_invalid" { "invalid source" } else if state.validation_status == "errored" { "validation failed" } else { "Source is valid" };
        return json_response(json!([{"source": "cv_folds: 3", "status": state.validation_status, "result_message": message}]));
    }
    if uri.starts_with("/rest/v1/convert_jobs") {
        if method == Method::POST {
            return json_response(json!([{"id": 22}]));
        }
        let pinescript = if state.convert_status == "completed" { Some("//@version=6") } else { None };
        let error_message = if state.convert_status == "errored" { Some("codegen failed") } else { None };
        return json_response(json!([{"status": state.convert_status, "pinescript": pinescript, "error_message": error_message}]));
    }

    json_response(json!([]))
}

fn mock_state(worker_query: &str, validation_status: &str, convert_status: &str, active_model: Option<String>) -> MockState {
    MockState {
        requests: Arc::new(Mutex::new(Vec::new())),
        experiment_response: Arc::new(Mutex::new(ExperimentResponse {
            count: 1,
            error_offset: None
        })),
        worker_query: worker_query.to_string(),
        validation_status: validation_status.to_string(),
        convert_status: convert_status.to_string(),
        active_model
    }
}

async fn serve_mock(state: MockState) -> (SupabaseClient, MockState, JoinHandle<()>) {
    let app = Router::new().route("/{*path}", any(postgrest)).with_state(state.clone());
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let handle = spawn(async move {
        serve(listener, app).await.unwrap();
    });
    let client = SupabaseClient::new(format!("http://{address}"), "test-key", None);
    (client, state, handle)
}

async fn analysis_with_status(worker_query: &str, validation_status: &str, convert_status: &str) -> (SupabaseClient, MockState, JoinHandle<()>) {
    let state = mock_state(worker_query, validation_status, convert_status, None);
    serve_mock(state).await
}

async fn analysis_with_benchmark(worker_query: &str, active_model: &str) -> (SupabaseClient, MockState, JoinHandle<()>) {
    let state = mock_state(worker_query, "completed_valid", "completed", Some(active_model.to_string()));
    serve_mock(state).await
}

async fn analysis(worker_query: &str) -> (SupabaseClient, MockState, JoinHandle<()>) {
    analysis_with_status(worker_query, "completed_valid", "completed").await
}

#[tokio::test]
async fn symbol_data_tools_use_repo_data() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../data/BTC_USDT.json");
    let body = read_to_string(path).await;
    let body = body.unwrap();
    let data = from_str::<Value>(&body);
    let data = data.unwrap();
    let timestamps = data["timestamps"].as_array();
    let timestamps = timestamps.unwrap();
    let first = timestamps.first();
    let first = first.unwrap();
    let first = first.as_str();
    let first = first.unwrap();
    let last = timestamps.last();
    let last = last.unwrap();
    let last = last.as_str();
    let last = last.unwrap();
    let expected_range = format!("{first} -> {last}");
    let actual_range = data_range("BTC_USDT").await;
    let actual_range = actual_range.unwrap();
    assert_eq!(actual_range, expected_range);

    let closes = data["close"].as_array();
    let closes = closes.unwrap();
    let mut total = 0.0;
    for close in closes {
        let close = close.as_f64();
        let close = close.unwrap();
        total += close;
    }
    let divisor = closes.len() as f64;
    let average = total / divisor;
    let value = Value::from(average);
    let formatted_average = format_value(&value);
    let expected_average = format!("Average close price for BTC_USDT: {formatted_average}");
    let actual_average = avg_price("BTC_USDT").await;
    let actual_average = actual_average.unwrap();
    assert_eq!(actual_average, expected_average);

    let missing_range = data_range("MISSING_SYMBOL").await;
    let missing_error = missing_range.is_err();
    assert!(missing_error);
}

#[tokio::test]
async fn queue_and_query_use_expected_postgrest_contract() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    assert_eq!(queue_experiment(&supabase, " Demo ", "cv_folds: 3", "owner").await.unwrap(), "queued id=9");
    let query = query_experiments(&supabase, "select:\n title", "owner").await.unwrap();
    assert!(query.contains("Public experiment (1)"));

    let requests = state.requests.lock().unwrap();
    let insert = requests.iter().find(|request| request.0 == Method::POST && request.1.starts_with("/rest/v1/experiments")).unwrap();
    assert_eq!(insert.2["source"], "cv_folds: 3");
    assert_eq!(insert.2["status"], "queued");
    assert_eq!(insert.2["user_id"], "owner");
    assert_eq!(insert.2["is_public"], false);
    assert!(insert.2.get("experiment").is_none());
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn experiment_loading_stops_after_a_short_page() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    set_experiment_response(&state, 50, None);

    let experiments = load_experiments(&supabase, None).await.unwrap();
    assert_eq!(experiments.len(), 50);
    let requests = completed_experiment_requests(&state);
    assert_eq!(requests.len(), 1);
    assert!(requests[0].contains("order=last_updated.desc,id.desc"));
    assert!(requests[0].contains("limit=100"));
    assert!(requests[0].contains("offset=0"));
    handle.abort();
}

#[tokio::test]
async fn experiment_loading_fetches_all_pages() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    set_experiment_response(&state, 201, None);

    let experiments = load_experiments(&supabase, None).await.unwrap();
    assert_eq!(experiments.len(), 201);
    let first = experiments.first().unwrap();
    let last = experiments.last().unwrap();
    assert_eq!(first["id"], 1);
    assert_eq!(last["id"], 201);
    let requests = completed_experiment_requests(&state);
    assert_eq!(requests.len(), 3);
    assert!(requests[0].contains("offset=0"));
    assert!(requests[1].contains("offset=100"));
    assert!(requests[2].contains("offset=200"));
    handle.abort();
}

#[tokio::test]
async fn experiment_loading_checks_for_an_empty_page_at_exact_boundary() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    set_experiment_response(&state, 200, None);

    let experiments = load_experiments(&supabase, None).await.unwrap();
    assert_eq!(experiments.len(), 200);
    let requests = completed_experiment_requests(&state);
    assert_eq!(requests.len(), 3);
    assert!(requests[2].contains("offset=200"));
    handle.abort();
}

#[tokio::test]
async fn experiment_loading_returns_page_errors_without_retrying() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    set_experiment_response(&state, 201, Some(100));

    let error = load_experiments(&supabase, None).await.unwrap_err();
    assert_eq!(error, "PostgREST error: [500] canceling statement due to statement timeout (code: 57014)");
    let requests = completed_experiment_requests(&state);
    assert_eq!(requests.len(), 2);
    assert!(requests[0].contains("offset=0"));
    assert!(requests[1].contains("offset=100"));
    handle.abort();
}

#[tokio::test]
async fn experiment_delete_requires_ownership() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    assert_eq!(delete_experiment(&supabase, 1, "owner").await.unwrap(), "deleted experiment id=1");
    let requests = state.requests.lock().unwrap();
    assert!(requests.iter().any(|request| request.0 == Method::DELETE && request.1.contains("user_id=eq.owner") && request.1.contains("id=eq.1")));
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn notebook_create_and_worker_persist_exact_status_bodies() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    let queries = vec!["select:\n title".to_string()];
    let notes = vec!["note".to_string()];
    assert_eq!(create_notebook(&supabase, " New notebook ", &queries, &notes, "owner").await.unwrap(), "created notebook id=3");
    assert!(process_notebook(&supabase).await.unwrap());

    let requests = state.requests.lock().unwrap();
    let insert = requests.iter().find(|request| request.0 == Method::POST && request.1.starts_with("/rest/v1/notebooks")).unwrap();
    assert_eq!(insert.2["title"], "New notebook");
    assert_eq!(insert.2["status"], "working");
    let update = requests.iter().rev().find(|request| request.0 == Method::PATCH && request.1.starts_with("/rest/v1/notebooks")).unwrap();
    assert_eq!(update.2["status"], "idle");
    assert_eq!(update.2["last_updated"], "now");
    assert_eq!(update.2["queries"][0]["results"][0]["values"][0], "Public experiment");
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn notebook_worker_persists_query_errors() {
    let (supabase, state, handle) = analysis("select:\n id").await;
    assert!(process_notebook(&supabase).await.unwrap());
    let requests = state.requests.lock().unwrap();
    let update = requests.iter().rev().find(|request| request.0 == Method::PATCH).unwrap();
    assert_eq!(update.2["status"], "errored");
    assert!(update.2["error_message"].as_str().unwrap().contains("`id` cannot be selected"));
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn validation_and_conversion_poll_terminal_states_and_preserve_insert_bodies() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    assert_eq!(validate_experiment(&supabase, "cv_folds: 3").await.unwrap(), "valid validation_id=21");
    assert_eq!(convert(&supabase, 1, 2, "pinescript", "owner").await.unwrap(), "//@version=6");
    let requests = state.requests.lock().unwrap();
    let validation = requests.iter().find(|request| request.0 == Method::POST && request.1.starts_with("/rest/v1/validation_jobs")).unwrap();
    assert_eq!(validation.2, json!({"source": "cv_folds: 3", "status": "working"}));
    let conversion = requests.iter().find(|request| request.0 == Method::POST && request.1.starts_with("/rest/v1/convert_jobs")).unwrap();
    assert_eq!(conversion.2, json!({"experiment_id": 1, "fold_idx": 2, "status": "working"}));
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn validation_and_conversion_return_terminal_error_text() {
    let (supabase, _, handle) = analysis_with_status("select:\n title", "completed_invalid", "errored").await;
    assert_eq!(validate_experiment(&supabase, "bad source").await.unwrap(), "invalid: invalid source");
    let error = convert(&supabase, 1, 0, "pinescript", "owner").await.unwrap_err();
    assert_eq!(error.to_string(), "pinescript job errored: codegen failed");
    handle.abort();
}

#[tokio::test]
async fn benchmark_create_and_delete_scope_requests_to_the_owner() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    let score_path = "results.mean:test_results.metrics.excess_sharpe";
    assert_eq!(create_benchmark(&supabase, " Bench ", score_path, "Oct 3 2026 00:00", "owner").await.unwrap(), "created benchmark id=5");
    assert_eq!(delete_benchmark(&supabase, 5, "owner").await.unwrap(), "deleted benchmark id=5");
    let invalid = create_benchmark(&supabase, "Bench", score_path, "sometime", "owner").await.unwrap_err();
    assert_eq!(invalid, "invalid cutoff: sometime");

    let requests = state.requests.lock().unwrap();
    let insert = requests.iter().find(|request| request.0 == Method::POST && request.1.starts_with("/rest/v1/benchmarks")).unwrap();
    assert_eq!(insert.2["title"], "Bench");
    assert_eq!(insert.2["score_path"], score_path);
    assert_eq!(insert.2["cutoff"], "2026-10-03T00:00:00");
    assert_eq!(insert.2["data"], json!({}));
    assert_eq!(insert.2["active_model"], Value::Null);
    assert_eq!(insert.2["user_id"], "owner");
    assert!(requests.iter().any(|request| request.0 == Method::DELETE && request.1.contains("user_id=eq.owner") && request.1.contains("id=eq.5")));
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn benchmark_listing_and_view_report_data_per_model() {
    let (supabase, _, handle) = analysis("select:\n title").await;
    let listed = list_benchmarks(&supabase, "owner").await.unwrap();
    assert_eq!(listed, "[BENCHMARKS] 1 benchmark(s)\nid=5 title=Benchmark cutoff=Jul 1 2026 00:00 active_model=none");

    let viewed = view_benchmark(&supabase, 5, "owner").await.unwrap();
    assert!(viewed.contains("score_path: results.mean:test_results.metrics.excess_sharpe"));
    assert!(viewed.contains("cutoff: Jul 1 2026 00:00"));
    assert!(viewed.contains("active_model: none"));
    assert!(viewed.contains("[MODEL] claude-opus-5 2 score(s)"));
    assert!(viewed.contains("scores: 0.100, 0.200"));
    assert!(viewed.contains("experiment_ids: 1, 2"));
    handle.abort();
}

#[tokio::test]
async fn enabling_benchmark_mode_clears_other_active_models() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    let enabled = enable_benchmark_mode(&supabase, 5, "claude-opus-5", "owner").await.unwrap();
    assert_eq!(enabled, "enabled benchmark mode id=5 model=claude-opus-5");

    let requests = state.requests.lock().unwrap();
    let updates = requests.iter().filter(|request| request.0 == Method::PATCH).collect::<Vec<_>>();
    assert_eq!(updates.len(), 2);
    assert_eq!(updates[0].2, json!({"active_model": null}));
    assert!(!updates[0].1.contains("id=eq.5"));
    assert_eq!(updates[1].2, json!({"active_model": "claude-opus-5", "last_updated": "now"}));
    assert!(updates[1].1.contains("id=eq.5"));
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn disabling_benchmark_mode_clears_every_active_model() {
    let (supabase, state, handle) = analysis_with_benchmark("select:\n title", "claude-opus-5").await;
    assert_eq!(disable_benchmark_mode(&supabase, "owner").await.unwrap(), "disabled benchmark mode");

    let requests = state.requests.lock().unwrap();
    let updates = requests.iter().filter(|request| request.0 == Method::PATCH).collect::<Vec<_>>();
    assert_eq!(updates.len(), 1);
    assert_eq!(updates[0].2, json!({"active_model": null}));
    assert!(updates[0].1.contains("user_id=eq.owner"));
    assert!(!updates[0].1.contains("id=eq.5"));
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn benchmark_mode_filters_every_past_experiment_reader() {
    let (supabase, state, handle) = analysis_with_benchmark("select:\n title", "claude-opus-5").await;
    list_experiments(&supabase, 0, "owner").await.unwrap();
    query_experiments(&supabase, "select:\n title", "owner").await.unwrap();
    experiment_source(&supabase, 1, "owner").await.unwrap();
    experiment_summary(&supabase, 1, "owner").await.unwrap();
    results_summary(&supabase, 1, "owner").await.unwrap();
    let select = vec!["title".to_string()];
    experiment_paths(&supabase, 1, &select, "owner").await.unwrap();
    convert(&supabase, 1, 0, "pinescript", "owner").await.unwrap();
    status(&supabase, 1, "owner").await.unwrap();

    let requests = state.requests.lock().unwrap();
    let experiment_requests = requests.iter().filter(|request| request.0 == Method::GET && request.1.starts_with("/rest/v1/experiments")).collect::<Vec<_>>();
    assert_eq!(experiment_requests.len(), 8);
    let filtered_requests = experiment_requests.iter().filter(|request| request.1.contains("last_updated.lte.2026-07-01")).collect::<Vec<_>>();
    assert_eq!(filtered_requests.len(), 7);
    assert!(filtered_requests.iter().all(|request| request.1.contains("id.in.")));
    let status_requests = experiment_requests.iter().filter(|request| !request.1.contains("last_updated.lte.2026-07-01")).collect::<Vec<_>>();
    assert_eq!(status_requests.len(), 1);
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn experiments_are_unfiltered_without_benchmark_mode() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    list_experiments(&supabase, 0, "owner").await.unwrap();
    query_experiments(&supabase, "select:\n title", "owner").await.unwrap();

    let requests = state.requests.lock().unwrap();
    let experiment_requests = requests.iter().filter(|request| request.1.starts_with("/rest/v1/experiments")).collect::<Vec<_>>();
    assert_eq!(experiment_requests.len(), 2);
    assert!(!experiment_requests.iter().any(|request| request.1.contains("last_updated.lte")));
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn active_model_without_data_only_sees_experiments_through_cutoff() {
    let (supabase, state, handle) = analysis_with_benchmark("select:\n title", "new-model").await;
    list_experiments(&supabase, 0, "owner").await.unwrap();

    let requests = state.requests.lock().unwrap();
    let request = requests.iter().find(|request| request.0 == Method::GET && request.1.starts_with("/rest/v1/experiments")).unwrap();
    assert!(request.1.contains("last_updated.lte.2026-07-01"));
    assert!(!request.1.contains("id.in."));
    drop(requests);
    handle.abort();
}

#[tokio::test]
async fn benchmark_mode_blocks_notebook_writes() {
    let (supabase, state, handle) = analysis_with_benchmark("select:\n title", "claude-opus-5").await;
    let queries = vec!["select:\n title".to_string()];
    let notes = vec!["note".to_string()];
    let error = create_notebook(&supabase, "Bench notes", &queries, &notes, "owner").await.unwrap_err();
    assert_eq!(error, "benchmark mode is enabled, notebooks are read-only");
    let update_error = update_notebook(&supabase, 7, Some("Renamed"), None, None, "owner").await.unwrap_err();
    assert_eq!(update_error, "benchmark mode is enabled, notebooks are read-only");

    let requests = state.requests.lock().unwrap();
    assert!(!requests.iter().any(|request| request.1.starts_with("/rest/v1/notebooks")));
    drop(requests);
    handle.abort();
}

#[tokio::test(start_paused = true)]
async fn validation_timeout_preserves_exact_message() {
    let (supabase, _, handle) = analysis_with_status("select:\n title", "working", "completed").await;
    let error = validate_experiment(&supabase, "cv_folds: 3").await.unwrap_err();
    assert_eq!(error.to_string(), "validation job id=21 did not complete within 60s");
    handle.abort();
}
