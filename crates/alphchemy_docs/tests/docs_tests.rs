use alphchemy_docs::content;
use alphchemy_docs::docs::{DOCS, DocsError, DocsIndex, list_doc_paths, read_doc, router};
use axum::body::Body;
use axum::http::{Request, StatusCode, header::{ACCESS_CONTROL_ALLOW_ORIGIN, CONTENT_TYPE}};
use axum::response::Response;
use http_body_util::BodyExt;
use tower::ServiceExt;

async fn response(path: &str) -> Response {
    let request = Request::builder().uri(path).body(Body::empty()).unwrap();
    router().oneshot(request).await.unwrap()
}

async fn body_text(response: Response) -> String {
    let bytes = response.into_body().collect().await.unwrap().to_bytes();
    String::from_utf8(bytes.to_vec()).unwrap()
}

#[test]
fn registry_preserves_document_order_and_content() {
    assert_eq!(DOCS.len(), 20);
    assert_eq!(DOCS[0].id, "Overview");
    assert_eq!(DOCS[0].path, "overview");
    assert_eq!(DOCS[0].body, content::OVERVIEW);
    assert!(content::OVERVIEW.contains("This page describes **Alphchemy**"));
    assert!(content::EXAMPLE.contains("total_entries, total_exits"));
    assert!(content::EXAMPLE.contains("mean_hold_time, std_hold_time"));
    assert!(content::QUERY.contains("10+50(title)"));
    assert!(content::QUERY.contains("`mean(<path>)`"));
}

#[test]
fn index_preserves_group_field_and_item_order() {
    let index = DocsIndex::default();
    assert_eq!(index.overview[0], "Overview");
    assert_eq!(index.overview[3], "Query");
    assert_eq!(index.experiment[2], "Example");
}

#[test]
fn library_lookup_requires_extensionless_relative_paths() {
    let paths = list_doc_paths();
    assert!(paths.contains(&"experiment/backtest"));
    assert!(paths.contains(&"source/source_format"));
    assert!(!paths.contains(&"experiment/backtest.md"));
    assert!(read_doc("experiment/backtest").unwrap().contains("# Backtest"));
    assert_eq!(read_doc("experiment/backtest.md"), Err(DocsError::NotFound));
    assert_eq!(read_doc("../AGENTS"), Err(DocsError::InvalidPath));
    let mut sorted = paths.clone();
    sorted.sort_unstable();
    assert_eq!(paths, sorted);
}

#[tokio::test]
async fn routes_serve_index_directory_ids_and_markdown_paths() {
    let index = response("/index").await;
    assert_eq!(index.status(), StatusCode::OK);
    assert_eq!(index.headers()[ACCESS_CONTROL_ALLOW_ORIGIN], "*");
    let index_body = body_text(index).await;
    assert!(index_body.starts_with("{\"Overview\""));

    let directory = response("/directory").await;
    assert_eq!(directory.status(), StatusCode::OK);
    assert!(body_text(directory).await.contains("experiment/backtest"));

    let overview = response("/doc/Overview").await;
    assert_eq!(overview.status(), StatusCode::OK);
    assert_eq!(overview.headers()[CONTENT_TYPE], "text/markdown; charset=utf-8");
    assert!(body_text(overview).await.contains("# Overview"));

    let backtest = response("/docs/experiment/backtest.md").await;
    assert_eq!(backtest.status(), StatusCode::OK);
    assert!(body_text(backtest).await.contains("# Backtest"));
}

#[tokio::test]
async fn routes_reject_bad_extension_missing_docs_and_traversal() {
    assert_eq!(response("/docs/index.txt").await.status(), StatusCode::BAD_REQUEST);
    assert_eq!(response("/docs/missing.md").await.status(), StatusCode::NOT_FOUND);
    let traversal = response("/docs/%2E%2E/AGENTS.md").await;
    assert_eq!(traversal.status(), StatusCode::BAD_REQUEST);
    assert_eq!(response("/doc/Missing").await.status(), StatusCode::NOT_FOUND);
}
