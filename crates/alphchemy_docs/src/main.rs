use std::io::Result;

use alphchemy_docs::docs::router;
use axum::serve;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<()> {
    let listener = TcpListener::bind("0.0.0.0:5050").await?;
    serve(listener, router()).await
}
