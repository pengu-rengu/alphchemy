use axum::{Json, Router};
use axum::extract::Path;
use axum::http::{HeaderValue, StatusCode, header::CONTENT_TYPE};
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use serde::Serialize;
use tower_http::cors::{Any, CorsLayer};

use crate::content;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Doc {
    pub id: &'static str,
    pub path: &'static str,
    pub body: &'static str
}

pub const DOCS: [Doc; 20] = [
    Doc { id: "Overview", path: "overview", body: content::OVERVIEW },
    Doc { id: "Results", path: "results", body: content::RESULTS },
    Doc { id: "Notebooks", path: "notebooks", body: content::NOTEBOOKS },
    Doc { id: "Query", path: "query", body: content::QUERY },
    Doc { id: "Source Format", path: "source/source_format", body: content::SOURCE_FORMAT },
    Doc { id: "Example", path: "source/example", body: content::EXAMPLE },
    Doc { id: "Experiment", path: "experiment/experiment", body: content::EXPERIMENT },
    Doc { id: "Backtest", path: "experiment/backtest", body: content::BACKTEST },
    Doc { id: "Strategy", path: "experiment/strategy", body: content::STRATEGY },
    Doc { id: "Overfitting", path: "experiment/overfitting", body: content::OVERFITTING },
    Doc { id: "Features", path: "features/features", body: content::FEATURES },
    Doc { id: "Indicators", path: "features/indicators", body: content::INDICATORS },
    Doc { id: "Network", path: "network/network", body: content::NETWORK },
    Doc { id: "Logic Network", path: "network/logic_net", body: content::LOGIC_NET },
    Doc { id: "Decision Network", path: "network/decision_net", body: content::DECISION_NET },
    Doc { id: "Actions", path: "actions/actions", body: content::ACTIONS },
    Doc { id: "Logic Actions", path: "actions/logic_actions", body: content::LOGIC_ACTIONS },
    Doc { id: "Decision Actions", path: "actions/decision_actions", body: content::DECISION_ACTIONS },
    Doc { id: "Optimizer", path: "optimizer/optimizer", body: content::OPTIMIZER },
    Doc { id: "Genetic", path: "optimizer/genetic", body: content::GENETIC }
];

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct DocsIndex {
    #[serde(rename = "Overview")]
    pub overview: [&'static str; 4],
    #[serde(rename = "Experiment")]
    pub experiment: [&'static str; 6],
    #[serde(rename = "Features")]
    pub features: [&'static str; 2],
    #[serde(rename = "Network")]
    pub network: [&'static str; 3],
    #[serde(rename = "Actions")]
    pub actions: [&'static str; 3],
    #[serde(rename = "Optimizer")]
    pub optimizer: [&'static str; 2]
}

impl Default for DocsIndex {
    fn default() -> Self {
        Self {
            overview: ["Overview", "Results", "Notebooks", "Query"],
            experiment: ["Experiment", "Source Format", "Example", "Backtest", "Strategy", "Overfitting"],
            features: ["Features", "Indicators"],
            network: ["Network", "Logic Network", "Decision Network"],
            actions: ["Actions", "Logic Actions", "Decision Actions"],
            optimizer: ["Optimizer", "Genetic"]
        }
    }
}

pub fn list_doc_paths() -> Vec<&'static str> {
    let mut paths = DOCS.iter().map(|doc| doc.path).collect::<Vec<_>>();
    paths.sort_unstable();
    paths
}

fn invalid_doc_path(path: &str) -> bool {
    path.starts_with('/') || path.split('/').any(|part| part == "..")
}

pub fn read_doc(path: &str) -> Result<&'static str, DocsError> {
    if invalid_doc_path(path) {
        return Err(DocsError::InvalidPath);
    }
    DOCS.iter().find(|doc| doc.path == path).map(|doc| doc.body).ok_or(DocsError::NotFound)
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DocsError {
    InvalidPath,
    NotFound
}

async fn index() -> Json<DocsIndex> {
    Json(DocsIndex::default())
}

async fn directory() -> Json<Vec<&'static str>> {
    Json(list_doc_paths())
}

fn markdown(body: &'static str) -> Response {
    let mut response = body.into_response();
    let content_type = HeaderValue::from_static("text/markdown; charset=utf-8");
    response.headers_mut().insert(CONTENT_TYPE, content_type);
    response
}

async fn doc_by_id(Path(id): Path<String>) -> Response {
    match DOCS.iter().find(|doc| doc.id == id) {
        Some(doc) => markdown(doc.body),
        None => StatusCode::NOT_FOUND.into_response()
    }
}

async fn doc_by_path(Path(path): Path<String>) -> Response {
    if invalid_doc_path(&path) {
        return (StatusCode::BAD_REQUEST, "doc_path must be relative to docs").into_response();
    }
    let Some(extensionless) = path.strip_suffix(".md") else {
        return (StatusCode::BAD_REQUEST, "doc_path must end with .md").into_response();
    };
    match read_doc(extensionless) {
        Ok(body) => markdown(body),
        Err(DocsError::InvalidPath) => (StatusCode::BAD_REQUEST, "doc_path must be relative to docs").into_response(),
        Err(DocsError::NotFound) => StatusCode::NOT_FOUND.into_response()
    }
}

pub fn router() -> Router {
    Router::new()
        .route("/index", get(index))
        .route("/directory", get(directory))
        .route("/doc/{id}", get(doc_by_id))
        .route("/docs/{*path}", get(doc_by_path))
        .layer(CorsLayer::new().allow_origin(Any))
}
