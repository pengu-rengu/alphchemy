use alphchemy_mcp::mcp_server::{router, supabase_from_env};
use axum::serve;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), String> {
    let supabase = supabase_from_env()?;
    let listener = TcpListener::bind("0.0.0.0:8000").await.map_err(|error| error.to_string())?;
    serve(listener, router(supabase)).await.map_err(|error| error.to_string())?;
    Ok(())
}
