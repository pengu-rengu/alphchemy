use std::sync::{Arc, Mutex};

use alphchemy_analysis::service::find_user_id;
use alphchemy_analysis::tools::experiment_tools::{convert, delete_experiment, list_experiments, queue_experiment, validate_experiment};
use alphchemy_analysis::tools::notebook_tools::{create_notebook, process_working_notebook};
use alphchemy_analysis::tools::query_tools::query_experiments;
use axum::serve;
use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::{Method, StatusCode};
use axum::response::Response;
use axum::routing::any;
use axum::Router;
use rust_supabase_sdk::SupabaseClient;
use serde_json::{Value, from_slice, json};
use tokio::net::TcpListener;
use tokio::spawn;
use tokio::task::JoinHandle;

#[derive(Clone)]
struct MockState {
    requests: Arc<Mutex<Vec<(Method, String, Value)>>>,
    worker_query: String,
    validation_status: String,
    convert_status: String
}

fn json_response(value: Value) -> Response {
    Response::builder().status(StatusCode::OK).header("content-type", "application/json").body(Body::from(value.to_string())).unwrap()
}

async fn postgrest(State(state): State<MockState>, request: Request) -> Response {
    let method = request.method().clone();
    let uri = request.uri().to_string();
    let bytes = to_bytes(request.into_body(), usize::MAX).await.unwrap();
    let body = if bytes.is_empty() { Value::Null } else { from_slice(&bytes).unwrap() };
    state.requests.lock().unwrap().push((method.clone(), uri.clone(), body));

    if uri.starts_with("/rest/v1/api_keys") {
        return json_response(json!([{"user_id": "owner"}]));
    }
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
            return json_response(json!([{
                "id": 1,
                "last_updated": "2026-07-01T00:00:00Z",
                "title": "Public experiment",
                "experiment": {"score": 2.0},
                "results": null,
                "status": "completed",
                "user_id": null,
                "is_public": true
            }]));
        }
        return json_response(json!([{"id": 1, "title": "Public experiment", "status": "completed"}]));
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

async fn analysis(worker_query: &str) -> (SupabaseClient, MockState, JoinHandle<()>) {
    analysis_with_status(worker_query, "completed_valid", "completed").await
}

async fn analysis_with_status(worker_query: &str, validation_status: &str, convert_status: &str) -> (SupabaseClient, MockState, JoinHandle<()>) {
    let state = MockState {
        requests: Arc::new(Mutex::new(Vec::new())),
        worker_query: worker_query.to_string(),
        validation_status: validation_status.to_string(),
        convert_status: convert_status.to_string()
    };
    let app = Router::new().route("/{*path}", any(postgrest)).with_state(state.clone());
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let handle = spawn(async move {
        serve(listener, app).await.unwrap();
    });
    let client = SupabaseClient::new(format!("http://{address}"), "test-key", None);
    (client, state, handle)
}

#[tokio::test]
async fn api_key_queue_and_query_use_expected_postgrest_contract() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    assert_eq!(find_user_id(&supabase, "valid-key").await.unwrap(), "owner");
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
async fn experiment_delete_requires_ownership_and_negative_offset_is_rejected() {
    let (supabase, state, handle) = analysis("select:\n title").await;
    let error = list_experiments(&supabase, -1, "owner").await.unwrap_err();
    assert_eq!(error, "offset must be >= 0");
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
    assert!(process_working_notebook(&supabase).await.unwrap());

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
    assert!(process_working_notebook(&supabase).await.unwrap());
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

#[tokio::test(start_paused = true)]
async fn validation_timeout_preserves_exact_message() {
    let (supabase, _, handle) = analysis_with_status("select:\n title", "working", "completed").await;
    let error = validate_experiment(&supabase, "cv_folds: 3").await.unwrap_err();
    assert_eq!(error.to_string(), "validation job id=21 did not complete within 60s");
    handle.abort();
}
