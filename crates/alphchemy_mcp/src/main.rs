use std::path::Path;

use alphchemy_analysis::service::supabase_from_env;
use alphchemy_mcp::mcp_server::router;
use axum::serve;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), String> {
    let supabase = supabase_from_env()?;
    let crate_root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let repo_root = crate_root.parent().and_then(Path::parent).ok_or("mcp crate must be under crates/".to_string())?;
    let data_root = repo_root.join("data");
    let listener = TcpListener::bind("0.0.0.0:8000").await.map_err(|error| error.to_string())?;
    serve(listener, router(supabase, data_root)).await.map_err(|error| error.to_string())?;
    Ok(())
}
