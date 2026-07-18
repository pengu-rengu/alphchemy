use std::sync::{Arc, Mutex};

use alphchemy_mcp::mcp_server::{McpServer, extract_api_key, router};
use axum::serve;
use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::{Method, StatusCode};
use axum::response::Response;
use axum::routing::any;
use axum::Router;
use http_body_util::BodyExt;
use rust_supabase_sdk::SupabaseClient;
use serde_json::{Value, from_slice, json};
use tokio::net::TcpListener;
use tokio::spawn;
use tokio::task::JoinHandle;
use tower::ServiceExt;

#[derive(Clone, Default)]
struct MockState {
    requests: Arc<Mutex<Vec<(Method, String, Value)>>>
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
        let rows = if uri.contains("api_key=eq.valid") { json!([{"user_id": "owner"}]) } else { json!([]) };
        return json_response(rows);
    }
    if uri.starts_with("/rest/v1/experiments") && method == Method::POST {
        return json_response(json!([{"id": 11}]));
    }
    json_response(json!([]))
}

async fn test_app() -> (Router, MockState, JoinHandle<()>) {
    let state = MockState::default();
    let api = Router::new().route("/{*path}", any(postgrest)).with_state(state.clone());
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let handle = spawn(async move {
        serve(listener, api).await.unwrap();
    });
    let client = SupabaseClient::new(format!("http://{address}"), "test-key", None);
    (router(client, "/tmp"), state, handle)
}

fn mcp_request(path: &str, body: Value, protocol_header: bool) -> Request<Body> {
    let mut builder = Request::builder()
        .method(Method::POST)
        .uri(path)
        .header("content-type", "application/json")
        .header("accept", "application/json, text/event-stream")
        .header("host", "localhost");
    if protocol_header {
        builder = builder.header("mcp-protocol-version", "2025-06-18");
    }
    builder.body(Body::from(body.to_string())).unwrap()
}

async fn body_text(response: Response) -> String {
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    String::from_utf8(bytes.to_vec()).unwrap()
}

#[test]
fn api_key_parser_requires_exactly_one_segment() {
    assert_eq!(extract_api_key("/mcp/key"), Ok("key"));
    assert_eq!(extract_api_key("/mcp"), Err("API key is required in the MCP URL"));
    assert_eq!(extract_api_key("/mcp/"), Err("API key is required in the MCP URL"));
    assert_eq!(extract_api_key("/mcp/key/extra"), Err("API key is required in the MCP URL"));
}

#[test]
fn server_registers_exactly_the_legacy_21_tools() {
    let client = SupabaseClient::new("http://127.0.0.1:1", "test-key", None);
    let server = McpServer::new(client, "/tmp");
    let mut names = server.tool_names();
    names.sort();
    let mut expected = vec![
        "alphchemy", "overview", "documentation", "avg_price", "queue_experiment",
        "validate_experiment", "queue_validated", "list_experiments", "query_experiments",
        "status", "experiment_source", "experiment_summary", "results_summary",
        "experiment_paths", "convert", "delete_experiment", "list_notebooks",
        "view_notebook", "create_notebook", "update_notebook", "delete_notebook"
    ];
    expected.sort();
    assert_eq!(names, expected);
}

#[tokio::test]
async fn middleware_returns_exact_missing_and_invalid_key_json() {
    let (app, _, handle) = test_app().await;
    let missing = app.clone().oneshot(mcp_request("/mcp", json!({}), false)).await.unwrap();
    assert_eq!(missing.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(body_text(missing).await, "{\"detail\":\"API key is required in the MCP URL\"}");

    let invalid = app.oneshot(mcp_request("/mcp/invalid", json!({}), false)).await.unwrap();
    assert_eq!(invalid.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(body_text(invalid).await, "{\"detail\":\"Invalid API key\"}");
    handle.abort();
}

#[tokio::test]
async fn valid_key_initializes_lists_tools_and_propagates_user_to_tool_calls() {
    let (app, state, handle) = test_app().await;
    let initialize = json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "test", "version": "1"}
        }
    });
    let initialized = app.clone().oneshot(mcp_request("/mcp/valid", initialize, false)).await.unwrap();
    let initialized_status = initialized.status();
    let initialized_body = body_text(initialized).await;
    assert_eq!(initialized_status, StatusCode::OK, "{initialized_body}");
    assert!(initialized_body.contains("serverInfo"));

    let list = json!({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}});
    let listed = app.clone().oneshot(mcp_request("/mcp/valid", list, true)).await.unwrap();
    assert_eq!(listed.status(), StatusCode::OK);
    let listed_body = body_text(listed).await;
    assert!(listed_body.contains("queue_experiment"));
    assert!(listed_body.contains("delete_notebook"));

    let call = json!({
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {"name": "queue_experiment", "arguments": {"title": "Demo", "source": "cv_folds: 3"}}
    });
    let called = app.oneshot(mcp_request("/mcp/valid", call, true)).await.unwrap();
    assert_eq!(called.status(), StatusCode::OK);
    assert!(body_text(called).await.contains("queued id=11"));

    let requests = state.requests.lock().unwrap();
    let insert = requests.iter().find(|request| request.0 == Method::POST && request.1.starts_with("/rest/v1/experiments")).unwrap();
    assert_eq!(insert.2["user_id"], "owner");
    assert_eq!(insert.2["is_public"], false);
    drop(requests);
    handle.abort();
}
